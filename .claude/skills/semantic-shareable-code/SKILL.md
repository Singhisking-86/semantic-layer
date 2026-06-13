---
name: semantic-shareable-code
description: >-
  Write, refactor, or review SQL and Python in this repo so that another analyst
  or Claude session can pick it up mid-project and continue without asking the
  author. Applies to SQL profiling queries, Python analysis scripts, and semantic
  artifact files. Every SQL file must carry a top block with its REGISTER ID,
  what it proves, and how to run it. Every Python script must be self-contained
  with a top-of-file contract. Outputs always land in domain/data/profiling_results/
  named by REGISTER ID. No side-effecting SQL (read-only only). Use whenever
  writing new SQL or Python, cleaning up existing scripts, or preparing
  deliverables. Adapted from [[shareable-code]] for semantic layer context.
---

# Semantic shareable code — another analyst picks this up cold and continues

The reader is the customer. The person who opens this file next — another analyst,
a future Claude session, or you three weeks later — must be able to understand
what it proves, run it, verify the result, and continue **without asking the
author**. Optimise for that reader.

Applies to: SQL profiling queries · Python analysis scripts · semantic layer
artifact files (metric registry YAML, tier README files, layer specs).

---

## SQL files — the top block is mandatory

Every `.sql` file committed to this repo must open with this block:

```sql
/* Register ID  : RET-STATE-01
 * What it proves: reconstructed state ③ (delivered) matches mart benchmark ±documented delta
 * Inputs        : PRODVM.ZZ_RETURN_IN_TRANSIT, PRODVM.HERMES_RETURN_TRACKING_DETAIL
 * Output        : returns/data/profiling_results/RET-STATE-01_state3_reconstruction.csv
 * Guardrails    : READ-ONLY · GE DATE - 150 · no warehousedb
 * Run (ad-hoc)  : python tools/teradata/pull.py --sql <this file> --out <output path>
 * Run (batch)   : python returns/scripts/run_sql.py <this file>
 * Status        : OPEN | ANSWERED | SUPERSEDED
 */
```

Each statement within the file must carry a `@name` marker that matches the REGISTER ID:

```sql
/* @name RET-STATE-01_state3_reconstruction */
SEL
    COUNT(*) AS delivered_count
FROM PRODVM.ZZ_RETURN_IN_TRANSIT
WHERE milestone_type = 'DELIVERED'
AND   event_date GE DATE - 150;
```

The `@name` marker is what the batch runner uses to name the output CSV.
If there is no `@name`, the output is anonymous and untrackable — do not omit it.

**Read-only hard rule.** No SQL file in this repo may contain CREATE / INSERT /
UPDATE / DELETE / COLLECT STATS / DROP / TRUNCATE. If materialisation is ever
needed, stop and ask — never write it speculatively.

---

## Python scripts — the seven habits (semantic-layer edition)

### 1. Top-of-file contract

```python
"""<One line: what this script produces and for whom.>

What it proves : <the specific assumption or metric this verifies>
Register IDs   : RET-STATE-01, RET-STATE-02  (questions this script answers)
Inputs         : PRODVM tables via Teradata · credentials: tools/teradata/credentials.json
Outputs        : returns/data/profiling_results/RET-STATE-01_<name>.csv
How to run     : python tools/teradata/pull.py --sql <sql file> --out <output>
                 OR: python returns/scripts/run_sql.py <sql file>   (batch mode)
Guard          : READ-ONLY — no CREATE/INSERT/UPDATE/DELETE/COLLECT STATS
Notes          : <the one Teradata dialect gotcha a new reader must know>
"""
```

### 2. Read top-to-bottom like a recipe
Order: imports → parameters → load/query → validate → transform → write output.
No forward references. Label each step.

### 3. Names say what, not how
`delivered_milestone_count`, not `n`. `build_state_reconstruction()`, not `proc()`.
If you need a comment to explain a name, the name is wrong.

### 4. Explain the WHY, not the WHAT
```python
# WHY: INSERTED_ON lag is median 1.6d, p95 3.6d — filter GE DATE - 150 gives
# ~148d of complete data; the last 2d are partial and excluded from rate calcs.
sample_window = "GE DATE - 150"    # GOOD

sample_window = "GE DATE - 150"    # set window    <- NOISE, delete
```

### 5. Validate loudly at every step
```python
assert len(df) > 0, "RET-STATE-01: zero rows returned — check credentials or date window"
assert "RETURNID" in df.columns, "RET-STATE-01: RETURNID column missing from result"
print(f"✔ RET-STATE-01: {len(df):,} rows · {df['RETURNID'].nunique():,} unique returns")
```

### 6. Small, single-purpose functions
Each function does one nameable thing. A reader can test or debug it in isolation.

### 7. Reproducible by anyone, anywhere
```python
# ── Parameters (change here, nowhere else) ────────────────────────────────────
SAMPLE_WINDOW_DAYS = 150          # Teradata: WHERE col GE DATE - N
DOMAIN             = "returns"
CREDS_PATH         = "tools/teradata/credentials.json"
```
No hard-coded dates from the system clock mid-file. No local paths buried in logic.

---

## Output naming — always by REGISTER ID

```
returns/data/profiling_results/RET-STATE-01_state3_reconstruction.csv
returns/data/profiling_results/REF-BRIDGE-01_wms_join_repair.csv
```

Format: `<REGISTER-ID>_<short_desc>.<ext>`. This is what the batch runner
produces automatically from the `@name` marker. Match it in any manual saves.

Never overwrite an existing result file without a new REGISTER ID or a version
suffix — a prior result may still be the evidence for a CONFIRMED verdict.

---

## Semantic artifact files (YAML, markdown specs)

Metric registry entries (`layers/data_layer/tier2_contracts/metric_registry/`):
- Follow the `_TEMPLATE_metric.yaml` exactly — `id`, `version`, `owner`,
  `definition`, `derivation`, `caveats`, `calibration_target`
- `calibration_target` must reference the benchmark it was verified against
  (e.g. the mart snapshot row count from docs/03)

Tier README files and ontology markdown:
- State explicitly: what is ACTIVE vs DESIGNED vs DEFERRED vs STUB
- Link to the REGISTER IDs whose findings grounded each design decision
- Don't describe what the code does — describe WHY this design was chosen

---

## Pre-share checklist (semantic edition)

Before committing or handing over any SQL or Python:

- [ ] SQL: top block present with REGISTER ID, what-it-proves, guardrails, run command
- [ ] SQL: every statement has a `/* @name <ID>_<desc> */` marker
- [ ] SQL: no CREATE/INSERT/UPDATE/DELETE/COLLECT STATS anywhere
- [ ] SQL: GE DATE - 150 filter on every event/fact table scan
- [ ] Python: top-of-file contract states register IDs, inputs, outputs, how to run
- [ ] Python: names are self-explanatory — no `df2`, `tmp`, `n` survivors
- [ ] Python: each step asserts what must be true with a clear message
- [ ] Python: checkpoints print row counts (e.g. `✔ RET-STATE-01: 560,912 rows`)
- [ ] Output path follows `<domain>/data/profiling_results/<ID>_<name>.csv`
- [ ] REGISTER.md row is OPEN before first run, ANSWERED after verdict is written
- [ ] Verdict written to docs/03 with row counts + percentages justifying it

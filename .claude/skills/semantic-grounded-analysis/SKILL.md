---
name: semantic-grounded-analysis
description: >-
  The DEFAULT operating mode for ALL data work in this repo — every SQL query,
  profiling run, join, derived metric, and source binding. Hard rules: READ-ONLY
  Teradata (SEL/HELP TABLE/DBC only), GE DATE - 150 cap, no warehousedb SELECT.
  Every question gets a stable REGISTER ID before SQL is written. Verdicts are
  CONFIRMED / FLAG / BLOCKER only. Findings go to docs/03_profiling_findings.md,
  register row flipped to ANSWERED. Never assume column names, types, or join keys —
  verify against data/catalog/db_table_column_name.csv or HELP TABLE first.
  Adapted from [[grounded-analysis]] for Teradata + semantic layer context.
---

# Semantic grounded analysis — prove it before you plan on it

Every assumption in a semantic layer plan is a bug waiting to happen. Column
names get assumed, join keys get guessed, value sets get enumerated from memory.
This skill makes **the data the authority** — not the plan, not the PBIX report,
not intuition. Adapted for the Teradata + semantic layer context of this repo.

**This is the default mode for ALL data work here**, whether or not a plan
told you to. If you are writing SQL, you are in this mode.

---

## Teradata hard rules (non-negotiable, enforced before any query)

```
READ-ONLY: only SEL/SELECT, HELP TABLE, SHOW VIEW/TABLE, EXPLAIN,
           and DBC dictionary queries (DBC.TablesV, DBC.ColumnsV).
           Never CREATE / INSERT / UPDATE / DELETE / COLLECT STATS
           on any production object. If materialisation is needed, stop and ask.

SAMPLING CAP: every exploratory query on event/fact tables must filter
              GE DATE - 150 (or tighter). History may extend to ~18 months
              (D4 decision), but not during exploration.

NO WAREHOUSEDB: never SELECT from warehousedb.*. The PBIX mart
                warehousedb.MB_ZZ_parcels is a reconciliation benchmark only —
                an offline snapshot. Build from PRODVM.* sources instead.

PRODVM PREFERRED: use PRODVM.* views. PRODVMUPD is the intraday path —
                  target-state only (Phase 3/NRT), do not build v1 against it.

DIALECT:
  SEL = SELECT · TOP n not LIMIT · date math: WHERE col GE DATE - 150
  DBC.ColumnsV: ColumnType is NULL for views — use HELP TABLE or check
                the base table instead
  CHAR comparisons need TRIM() to handle trailing spaces
  Use LOWER() when matching names from DBC
```

---

## Before writing any SQL — check the catalog first

`data/catalog/db_table_column_name.csv` is a 94,983-row dump of DBC.ColumnsV
covering BICOEDB, Merchanddb, PO_VM, PRODVM, WAREHOUSEDB. **Check it before
querying DBC** — it saves a round-trip and avoids dialect pitfalls.

If the column or table isn't in the catalog, then query DBC or run HELP TABLE.

---

## REGISTER.md is the authority — not ad-hoc files

Every investigative SQL question gets a **stable, topic-keyed ID** in the domain's
`sql/REGISTER.md`. Assigned once, never renumbered, never reused.

| Prefix | Domain |
|--------|--------|
| `RET-` | Returns logistics |
| `REF-` | Refunds |
| `CON-` | Customer contacts / support |
| `MER-` | Merchandising |
| `CAT-` | Catalog discovery (cross-domain) |

Workflow per question:
1. Add an OPEN row to REGISTER.md with the ID and question before writing SQL
2. Annotate the SQL statement: `/* @name RET-STATE-01_reconstruction */`
3. Run → result lands in `data/profiling_results/RET-STATE-01_reconstruction.csv`
4. Write verdict to `docs/03_profiling_findings.md` with rows + percentages
5. Flip the register row to ANSWERED with the doc reference

The old inline P-/Q-numbers are historical — trust the register, not the numbers.

---

## Pillar 1 — Schema is discovered, never assumed

- **Verify every table, column, and value before using it.** Check
  `data/catalog/db_table_column_name.csv` first, then DBC or HELP TABLE.
  Do NOT write a query against a column name you have not confirmed.
- **Persist what you find as config.** If you discover a schema fact, write it
  to the domain's tier 3 bindings or as a comment in the SQL register. The
  catalog is the contract — not memory.
- **Distinct categorical values are facts to query**, never enumerated from memory
  (e.g. ORDERSTATUS values, RETURN_EVENT_CODE vocabulary).
- **Badge every field:** EXPLICIT (observed in data) / INFERRED (your interpretation)
  / CONFIRMED (human-reviewed). Never let inferred pass as fact.
- **Join keys are assumptions until validated.** A 0% match rate is a BLOCKER
  (see P13: ORDERNUMBER ≠ ORDER_SERIAL_NUMBER). Prove the join before building on it.

## Pillar 1b — No silent inclusion or exclusion

Deciding what data is "relevant" — a whitelist, filter, sample, dropped rows —
is a semantic decision, never a neutral one. It must never be made silently.

- **Enumerate IN and OUT before computing.** For every classification or
  aggregation, produce a considered-vs-dropped ledger: which values/events drive
  the result, which are ignored, with counts and why.
- **Dropping requires permission or explicit surfacing.** Default to ALL; if you
  scope down, say so and get agreement.
- **Name the risk of each drop.** "CDC lag rows excluded → freshness undercounted."
  Silent truncation reads as "covered everything" when it isn't.

## Pillar 2 — Lineage persists in the outputs

- Every transformation writes its logic to the outputs alongside the result:
  source table(s), filters, joins, group-by grain, exact SQL expression.
- For each result, record: the REGISTER ID, the SQL file path, the run date,
  and the row count. A reviewer must trace any number back to raw data without
  re-running.
- Durable artifacts: `docs/03_profiling_findings.md` (verdicts) +
  `sql/REGISTER.md` (ID status) + `data/profiling_results/` (evidence CSVs).

## Pillar 3 — Declare types and empty-value handling

- **State each input's actual type** (from the data, not assumed) before arithmetic.
  Teradata CHAR vs VARCHAR vs INTEGER vs TIMESTAMP — do not treat a CHAR-coded
  number as an integer without explicit cast.
- **Cast explicitly** and record the cast in the SQL comment.
- **Declare the null/empty rule** for every aggregate: are nulls dropped, treated
  as 0, or their own category? Wrong null handling silently corrupts rates.
- **Denominators are explicit:** state what each rate is over and how zero/null
  rows count. Return rate denominator = order lines, not returns.

---

## Verdict taxonomy

Every finding in `docs/03_profiling_findings.md` gets exactly one verdict:

| Verdict | Meaning |
|---------|---------|
| `CONFIRMED` | Verified by data; row counts + percentages stated |
| `FLAG` | Anomaly noted; not blocking; documented for future handling |
| `BLOCKER` | Blocks downstream work until resolved (e.g. P13 join key mismatch) |

Never use any other label. Never leave a finding without a verdict.

---

## Runners

| Use case | Command |
|----------|---------|
| Ad-hoc single query, preview | `python tools/teradata/pull.py --sql <file>` |
| Ad-hoc single query, save CSV | `python tools/teradata/pull.py --sql <file> --out <path>` |
| Multi-statement batch (@name → CSV) | `python returns/scripts/run_sql.py <file>` |

---

## Done means

From the persisted artifacts alone — REGISTER.md + docs/03 + CSVs — a reviewer
can answer: what every query proved, what each column's type was, how empties
were handled, what was dropped and why, **without re-running anything or asking
the author**.

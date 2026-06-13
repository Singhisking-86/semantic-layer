# N Brown Returns — AI-First Semantic Layer

Building a detailed, evidence-grounded understanding of the returns and refunds
processes (and later associated customer contacts), encoded in a **semantic model
decoupled from source systems** — process ontology → semantic contracts
(metrics-as-code + agent-readable catalog) → source bindings — so the model is
maintained and enhanced as processes evolve. This is the **Data layer** of a four-layer NB-OS stack (Data → Infrastructure &
Integration → Intelligence → Application). We are building the Data layer now,
engine-agnostic; Databricks implementation is the deferred Infrastructure &
Integration layer. The Intelligence layer (insight discovery, problem analysis,
action recommendation, impact assessment) and Application layer (24×7 reporting,
constant optimization HIL + agentic, conversational) consume the Data layer. Two
PBI reports were mined as seed knowledge and serve only as a calibration benchmark.

**If you are Claude Code: start with [`CLAUDE.md`](CLAUDE.md).** It contains the
guardrails (read-only, 150-day sampling, no warehousedb), established facts, and
the run queue.

## Layout

```
CLAUDE.md                  Project memory for Claude Code — read first
docs/
  00_vision_target_architecture.md  Objective, 3-tier decoupling, layer designs
  01_decision_log.md       Binding decisions D1–D8 + business flow
  02_source_catalog.md     PBIX→Teradata source resolution map
  03_profiling_findings.md P1–P14 & Q1–Q5 evidence + L1 load rules R1–R7
  04_state_model_spec.md   Target L1 entities, state rules, measures, gate
  05_open_questions.md     Run queue (P15–P17, Q7–Q19) and phase gate
sql/
  REGISTER.md              Single source of truth: question IDs → status → verdict
  open/                    Live queue (runner-ready)
  answered/                Ran; verdicts in docs/03
  archive/                 Superseded drafts (never run; see _WHY_ARCHIVED.md)
scripts/
  td.py                    teradatasql connection + read-only guard
  run_sql.py               Run a .sql file → one CSV per statement
data/
  profiling_results/       Raw CSV evidence (P1–P14, p11)
  catalog/                 DBC.ColumnsV dump (94,983 rows, 5 databases)
reference/
  PBIX extraction, execution plan, ER-model & lineage HTML reports,
  pandas replication scripts, business flow doc
layers/                    NB-OS stack — DESIGNED artifacts (see layers/README.md)
  data_layer/              ACTIVE: tier1_ontology / tier2_contracts / tier3_bindings
  infra_integration_layer/ DEFERRED placeholders (Databricks, AO, deploy, actions)
  intelligence_layer/      TARGET placeholders (services, skills, action_catalog)
  application_layer/       TARGET placeholders (reporting, optimization, conversational)
```

Discovery work (evidence + SQL) lives at the repo root; `layers/` holds the
designed semantic artifacts. Right now only `layers/data_layer/` is active.

## Setup

```bash
python -m venv .venv && source .venv/bin/activate   # or your env manager
pip install -r requirements.txt
cp .env.example .env                                 # fill TD_USER / TD_PASSWORD
python -c "from scripts.td import query; print(query('SEL DATE'))"   # smoke test
```

Then work the queue:

```bash
python scripts/run_sql.py sql/open/P15_P17_next_batch.sql
```

## Status (as of 2026-06-12)

- Phase 0–1: PBIX extraction ✅ · source resolution ✅ · profiling P1–P14 ✅ ·
  mart reconstruction proof Q1–Q5 ✅ · CDC freshness P11 ✅
- Open: **P13 bridge blocker** (ZZ→WMS key mismatch, repair = P15),
  P16 event decode, P17 ORDERSTATUS, validation Q7–Q19; domain 3 (customer
  contacts) discovery = C-series, not started.
- Phase 1 exits when the bridge is fixed and Q15–Q19 calibrate live-rebuilt
  states against the mart benchmark. Then Phase 2: first versioned cut of all
  three semantic-layer tiers for returns + refunds.

The PBIX files themselves (~120 MB) are not in the repo; keep them wherever you
store large artifacts. Everything extracted from them is in `reference/`.

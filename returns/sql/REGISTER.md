# SQL Register — single source of truth

Every investigative question has ONE stable, topic-keyed ID assigned once and never
renumbered. This register maps each ID to its question, status, the file that holds
the SQL, and where the verdict is recorded. **When in doubt, this file wins** over
any numbering inside individual SQL files (the old P-/Q-numbers are historical and
collide across files — see the legend at the bottom).

## ID scheme

`<DOMAIN>-<TOPIC>-<NN>` — assigned once, append-only, never reused.
Domains: `RET` returns logistics · `REF` refunds · `CAT` catalog/schema discovery
· `CON` customer contacts (future). Status: `OPEN` (in queue) · `ANSWERED`
(verdict in docs/03) · `DEAD` (question void — e.g. needs warehousedb) ·
`SUPERSEDED` (re-asked under a newer ID/run).

## Folder lifecycle

- `sql/open/` — live queue, runnable now.
- `sql/answered/` — ran; verdict captured in `docs/03_profiling_findings.md`.
- `sql/archive/` — superseded drafts, kept for provenance, never run
  (see `archive/_WHY_ARCHIVED.md`).

## Register

| ID | Question | Status | SQL location (legacy #) | Verdict |
|----|----------|--------|--------------------------|---------|
| RET-GRAIN-01 | Is the request grain one row per (RETURNID, ORDERNUMBER, ORDERLINEITEMNUMBER)? | ANSWERED | answered/…FINAL (P1); archive Q20 | CONFIRMED — unique on 1,192,901 rows. docs/03 P1 |
| RET-GRAIN-02 | Lines-per-return distribution | ANSWERED | answered/…FINAL (P2) | avg 2.13, 53% single, max 44. docs/03 P2 |
| RET-GRAIN-03 | Repeated (RETURNID, SKU) = qty rows or distinct order lines? | ANSWERED | answered/…FINAL (P3); archive Q21 | all distinct order lines. docs/03 P3 |
| RET-GRAIN-04 | Can one order line appear under >1 RETURNID (re-requests)? | ANSWERED | answered/…FINAL (P4); archive Q24 | 1.1% do → rule R4. docs/03 P4 |
| RET-TRANSIT-01 | TRACKINGID 1:1 with RETURNID? null rate? | ANSWERED | answered/…FINAL (P5) | ≤1 each; 5.7% null. docs/03 P5 |
| RET-TRANSIT-02 | In-transit cardinality + duplicate (RETURNID, ts) rows | ANSWERED | answered/…FINAL (P6); archive Q22 | 3,285 dups → rule R1. docs/03 P6 |
| RET-TRANSIT-03 | Events per return: milestone log or step history? row semantics | ANSWERED | answered/…FINAL (P7,P8); archive Q23 | ≤3 rows; row1=②, row2=③ → R2,R3. docs/03 P7,P8 |
| RET-XTABLE-01 | Same RETURNID & TRACKINGID across requested + in-transit? | ANSWERED | answered/…FINAL (P9) | 90.7% covered, 0 mismatches. docs/03 P9 |
| RET-COL-01 | RETURNOPTION = return method? | ANSWERED | answered/…FINAL (P10) | DEAD (constant '1'). docs/03 P10 |
| RET-CDC-01 | INSERTED_ON lag vs request time → watermark + freshness | ANSWERED | answered/…FINAL (P11) | median 1.6d, p95 3.6d → rule R7. docs/03 P11 |
| RET-COL-02 | Channel/value column fill rates (NOTES, RETURNCOST, etc.) | ANSWERED | answered/…FINAL (P12) | 3 dead, RETURNCOST/WHREF live. docs/03 P12 |
| RET-STATE-01 | State-② first-carrier-scan coverage & lag (mature cohort) | OPEN | open/Revised (Q16) | — |
| RET-STATE-02 | State-④ WH-processed coverage from each signal (EVRI P394, ZZ delivered) | OPEN | open/Revised (Q17) | — |
| RET-STATE-03 | Reconstruction parity: daily state counts from events vs benchmark | OPEN | open/Revised (Q19) | Phase-1 exit gate |
| RET-REASON-01 | Reason taxonomy + volume on live 150d | OPEN | open/Revised (Q7) | — |
| RET-HIST-01 | History depth per source (supports 18-month plan) | OPEN | open/Revised (Q9) | — |
| RET-FRESH-01 | Freshness: latest event per source | OPEN | open/Revised (Q10) | — |
| RET-ORDERSTATUS-01 | ORDERSTATUS 6-value profile — portal-side state signal? | OPEN | open/P15_P17 (P17) | — |
| RET-SCHEMA-01 | Columns of the request source (HELP TABLE) | OPEN | open/Revised (Q8) | — |
| REF-BRIDGE-01 | Do ZZ requests link to PRODVM.RETURN_ITEM? (the blocker) | OPEN | open/P15_P17 (P13→P15a/b) | P13 was 0% match; P15 diagnoses+repairs |
| REF-VOCAB-01 | Decode RETURN_EVENT_CODE; confirm 0097 = credit | OPEN | open/P15_P17 (P16) | candidate from P14 (0097 100% on credited) |
| REF-SIGNAL-01 | WH event vocabulary + credited coverage | ANSWERED | answered/…FINAL (P14) | 0097 = refund candidate. docs/03 P14 |
| REF-DISCOVERY-01 | Refund/payment source discovery (CREDITED_IND, POSTAGE_REFUND, refund_type_code, RETURN_NOT_CREDITED) | OPEN | open/Revised (Q11) | — |
| REF-EVENTVOCAB-FULL | Full event vocabulary on live 150d (confirm 90d PBIX profile) | OPEN | open/Revised (Q18) | — |
| RET-NRT-01 | PRODVM vs PRODVMUPD freshness (sizing NRT path) | OPEN | open/Revised (Q12) | — |
| RET-KEYMAP-01 | How requests link to each event stream (coverage per stream) | OPEN | open/Revised (Q15) | — |
| RET-PAYMENT-01 | Payment-method signal in the orderline source | OPEN | open/Revised (Q14) | — |
| CAT-SWEEP-01 | DBC sweep: all returns/refund/parcel/carrier/WH objects | ANSWERED | answered/Catalog (Q25–Q29) | produced data/catalog dump. docs/02 |
| CON-* | Customer-contact discovery | OPEN (not started) | — (author C-series) | docs/05 domain 3 backlog |

## Mart-reconstruction questions (run offline on the PBIX snapshot, not on Teradata)

| ID | Question | Status | Verdict |
|----|----------|--------|---------|
| MART-01..05 | Grain / ordering / status partition / SLA / SoS reconstructability (legacy Q1–Q5) | ANSWERED | all reconstructable → REBUILD; mart = calibration only. docs/03 Q1–Q5 |

## Working rule going forward

1. New question → assign the next free ID in its domain, add a row here as OPEN,
   put the SQL in `sql/open/` with an `@name` matching the ID.
2. Ran it → move SQL to `sql/answered/` (or leave in a multi-question file),
   write the verdict into `docs/03`, flip the row to ANSWERED with the doc ref.
3. A question becomes void → mark DEAD with one line on why; if re-asked better,
   mark the old row SUPERSEDED and point to the new ID. Never renumber.
4. The old inline P-/Q-numbers stay inside the SQL files as-is (historical);
   this register is the bridge. Don't propagate them to new work — use IDs.
5. When one register ID spans several SQL statements (e.g. REF-BRIDGE-01 has
   key-format probes + match tests; RET-STATE-02 has EVRI + ZZ variants;
   REF-EVENTVOCAB-FULL has ZZ-status + EVRI-code queries), each statement gets a
   distinct `@name` suffix under the same ID
   (`REF-BRIDGE-01_via_whref`, `RET-STATE-02_state4_via_evri_p394`, …) so the
   runner writes one CSV per statement without collision.

## Legacy-number legend (why the collisions existed)

- **Q1–Q5** = mart reconstruction (offline) → MART-01..05.
- **Q6, Q13** = DEAD (needed warehousedb).
- **Q7–Q19** = live source/state queue, in `open/Revised`.
- **Q20–Q24** = early grain probes with guessed columns → SUPERSEDED by P1–P9.
- **Q25–Q29** = catalog sweep → CAT-SWEEP-01 (done).
- **P0** = schema probe (draft) → SUPERSEDED. **P1–P14** = canonical profiling run.
- **P15–P17** = current open batch (bridge/vocab/orderstatus).

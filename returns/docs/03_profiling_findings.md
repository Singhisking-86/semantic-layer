# 03 · Profiling Findings — Evidence Register

All measurements on a 150-day window unless stated. Raw result CSVs in
`data/profiling_results/`. Visual version: `reference/Returns_Profiling_ER_Model.html`.

## Q-series — mart reconstruction validation (run offline on the embedded PBIX
## snapshot of warehousedb.MB_ZZ_parcels: 730,982 parcels, refresh 2026-05-19)

| ID | Question | Verdict |
|----|----------|---------|
| Q1 | Mart grain | CONFIRMED — 1 row/RETURNID; 1:1 TRACKINGID |
| Q2 | Event ordering | NEAR-PERFECT — 1 scan<request; 0 handover<scan; 2,495 WH<handover (③ is "last carrier scan", can postdate ④); 10 processed-with-no-scan |
| Q3 | Status partition | EXACT — Idle/InTransit/WH-WIP/Processed partition the Requested population with zero overlap/gap |
| Q4 | SLA flag | EXACT — SLA = (④−② ≤ 10 days); population = has-② (665,210; pass 634,093) |
| Q5 | SoS legs | Pure date arithmetic — legs 1/2/4 zero mismatch; leg 3 had 2,492 negative-leg cases (same ③-definition artifact as Q2) |

**Conclusion (drives D3):** every mart flag is reconstructable from PRODVM events →
REBUILD; the mart is the reconciliation benchmark only. The Q4/Q3 counts above are
the Phase-1 exit reconciliation targets.

## P-series — source profiling (run on Teradata, 150d)

| ID | Finding | Verdict |
|----|---------|---------|
| P1 | (RETURNID, ORDERNUMBER, ORDERLINEITEMNUMBER) unique on 1,192,901 rows / 560,912 returns; 0 null order keys/SKU; 68,272 null TRACKINGID (5.7%) | CONFIRMED grain |
| P2 | 53.0% single-line returns; avg 2.13 lines; max 44 | header entity real |
| P3 | All 22,361 repeated (RETURNID, SKU) pairs = different order lines; no qty rows | line = order line |
| P4 | 13,173 order lines (1.1%) carry 2–6 return requests | FLAG → rule R4 |
| P5 | 0 trackings: 32,156 returns (5.7%); exactly 1: 528,756; never >1 | return = parcel |
| P6 | in-transit: 984,213 rows / 527,986 returns (= distinct trackings); 3,285 dup (RETURNID, ts) rows (0.33%) | FLAG → rule R1 |
| P7 | events/return: 1→74,888 (13.4%), 2→449,969 (85.2%), 3→3,129 (0.6%) | milestone log |
| P8 | row1: IN_TRANSIT 436,196 (82.6%), DELIVERED 70,400 (13.3%), OTHER 20,986, DROPPED_OFF 404. row2: DELIVERED 449,951 (99.3%). row3: all DELIVERED | row1=②, row2=③; FLAG → rules R2, R3 |
| P9 | 508,989/560,912 returns (90.7%) have transit rows; 0 TRACKINGID mismatches | key hygiene perfect; 9.3% = Idle → rule R6 |
| P10 | RETURNOPTION constant '1' on all rows | DEAD column |
| P11 | CDC lag (INSERTED_ON − DATETIMEREQUESTED), 49,931-row sample: median 1.64d, mean 1.75d, p95 3.60d, max 3.80d; buckets <1d 25.7%, 1–2d 46.4%, 2–3d 17.4%, 3–4d 10.1%; six fractional-second batch signatures cover 99.6% of rows (~daily loads); 188 rows (0.38%) negative lag, worst −24.3d | FLAG → rule R7; D5 freshness ceiling |
| P12 | Fill rates: NOTES 0%, VOUCHERVALUE 0%, EXTERNALREFERENCE 0%, RETURNCOST 100%, WAREHOUSEREFERENCE 99.66%; ORDERSTATUS 6 distinct; RETAILER 2 distinct | RETURNCOST = unused asset; ORDERSTATUS → P17 |
| P13 | ZZ→RETURN_ITEM join on TRIM(ORDERNUMBER)=ORDER_SERIAL_NUMBER: **0 / 1,192,901 matched** | **BLOCKER** → P15a/b |
| P14 | WH event vocab (events_, credited_rows): 0002 1,421,347/1,274,557 · 8092 1,275,042/1,143,625 · 8093 1,273,777/1,142,266 · 0001 1,273,754/31,620 · **0097 1,244,064/1,244,064 (100%)** · 0099 88,508/2,966 · 0296 86,795/81,646 · 0293 86,457/81,442 · 0295 85,556/80,413 · 1507 79,870/0 · 1506 39,573/492 · long tail | 0097 = refund-event candidate; decode → P16 |

Working hypotheses on the WH vocabulary (to verify with P16): 0001 = booked-in
(only 2.5% credited at that point), 0002 = processed, 8092/8093 = movement scans,
1507/1533/1516 = non-credit outcomes (0% credited).

## L1 load rules (binding — forced by the amber/red findings)

| Rule | Trigger | Statement |
|------|---------|-----------|
| R1 | P6 | Dedupe ZZ_RETURN_IN_TRANSIT on (RETURNID, DATETIMEINTRANSIT); keep DELIVERED-class status over others; log discard count as a DQ metric. |
| R2 | P7/P8 | State ③ = FIRST DELIVERED-class milestone. Later DELIVERED rows are retained as raw events, never state changes. |
| R3 | P8 | If no IN_TRANSIT row, take ② from the first EVRI scan; if neither exists, ② is null and the return is excluded from the SLA population (matches mart behaviour, Q4). |
| R4 | P4 | Add `request_attempt_seq` per order line. Return Rate counts an order line as returned once (latest completed attempt). |
| R5 | P5 | Null-TRACKINGID returns are valid ① returns ("no-label cohort"); surfaced, never dropped. They simply cannot join carrier streams. |
| R6 | P9 | Requests with no transit rows = Idle population; handled natively by current-state derivation. |
| R7 | P11 | Incremental load watermark on INSERTED_ON with a 7-day reprocessing window (catches late + amended rows via UPDATED_ON). "Data as of" on every serving surface = MAX(INSERTED_ON), never calendar yesterday. Negative-lag rows loaded but tagged as a DQ anomaly cohort. |

## EVRI vocabulary (from embedded PBIX copies — confirm on live 150d)

- P394 = RETURNED TO WAREHOUSE → state ④ signal from the carrier side.
- ZZ "Delivered to Retailer"-class statuses → ③.
- ~6.4 events/parcel average.

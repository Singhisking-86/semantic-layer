# 02 · Source Catalog & Resolution Map

How every PBIX source resolves to a queryable Teradata object. PBIX-qualified names
take priority; unqualified names resolve through the PRODVM view layer. Discovery
was done via DBC.TablesV/ColumnsV (case-insensitive LOWER matching; views return
NULL ColumnType — use HELP TABLE or the base table) plus the full column dump in
`data/catalog/db_table_column_name.csv`.

## Primary sources (build from these)

| Object | Type | Role | Key facts |
|--------|------|------|-----------|
| `PRODVM.ZZ_RETURN_REQUESTED` (view over `Production.ZZ_RETURN_REQUESTED`) | V | State ① + reasons + bridge keys | 22 cols. Grain (RETURNID, ORDERNUMBER, ORDERLINEITEMNUMBER) unique. Has RETURNCOST (100% filled), WAREHOUSEREFERENCE (99.7%), ORDERSTATUS (6 values), RETAILER (2), INSERTED_ON/UPDATED_ON (CDC). Dead: RETURNOPTION (constant '1'), NOTES, VOUCHERVALUE, EXTERNALREFERENCE. |
| `PRODVM.ZZ_RETURN_IN_TRANSIT` (view over `Production.ZZ_RETURN_IN_TRANSIT`) | V | States ② & ③ | 4 cols: RETURNID, DATETIMEINTRANSIT, TRACKINGID, LASTTRACKINGSTATUS. Milestone log ≤3 rows/return. 3,285 dup (RETURNID, ts) rows on 150d → rule R1. |
| `PRODVM.HERMES_RETURN_TRACKING_DETAIL` (view over Production_Daily_Updated_01) | V | EVRI step telemetry, ④ signal | Join HERMES_BARCODE = TRACKINGID. ~6.4 events/parcel. Event P394 = RETURNED TO WAREHOUSE. Decode via despatch_event_code (prod copy unresolved — only DEVT copies visible in dictionary; confirm in P-batch if needed). |
| `PRODVM.RETURN_ITEM` | V | State ④ + refund outcome | Keys: RETURN_NUMBER; ACCOUNT + TRADING + ORDER_SERIAL_NUMBER + ORDERLINE_NUMBER. CUSTOMER_CREDITED_IND, POSTAGE_REFUND_VALUE, RETURN_DATE/TIME. |
| `PRODVM.RETURN_ITEM_EVENT_HISTORY` | V | WH event stream, ⑤ signal | EVENT_CODE/DATE/TIME. ~7.4M events/150d. 0097 = credit candidate (100% on credited). Decode table: `PRODVM.RETURN_EVENT_CODE`. Also: RETURN_NOT_CREDITED, refund_type_code. |
| `PRODUCTION_ORDERLINE.orderline_current` | T | Demand base (Return Rate denominator) | Keys ACCOUNT + TRADING_CODE + ORDER_SERIAL_NUMBER + ORDERLINE_NUMBER. PBIX filtered status '0', 90d. |
| `prodvm.calendar_mart` | ? | Conformed calendar | PBIX-qualified; 4 role-playing copies in PBIX. Fin year Mar–Feb, Q3 = 4 periods. Not found in dictionary dump — confirm access. |

## Dimension sources (Return Reasons report)

| Object | Notes |
|--------|-------|
| `PRODUCTION_REFRESH.product_summary` | Product master. SKU parsing: chars 1–5 = product number, last 2 = option. |
| `Production_Reference.product_status_code` | Status decode. |
| `zendor_daily_updated_02.product_option` | Option/size decode. |
| `PRODVM.SUPPLIER_NEW` (over PRODUCTION_DAILY_UPDATED_02.SUPPLIER_NEW) | Supplier dim. Known flaw inherited from PBIX: multi-supplier products made Return-Rate `Table.Distinct` non-deterministic — fix in L1, don't replicate. |

## Benchmark only (no SELECT access)

| Object | Notes |
|--------|-------|
| `warehousedb.MB_ZZ_parcels` | The PBIX mart. 730,982-row embedded snapshot (refresh 2026-05-19) profiled offline; Q1–Q5 proved every flag reconstructable. Reconciliation targets recorded in docs/03. |
| `WAREHOUSEDB.zz_return_requested_clean` | Used by PBIX Returns-Rate join; its ORDER_NUMBER aligns with orderline ORDER_SERIAL_NUMBER directly (unlike the raw ZZ table — see P13 blocker). |
| `WAREHOUSEDB.MB_WH_return_scans`, `fact_returns` | Exist per catalog; unexplored. |

## Customer ID quirk

PBIX: `CustomerID = account × 10` (Tcustnum-style with check digit context).
Bear in mind for any account-level joins.

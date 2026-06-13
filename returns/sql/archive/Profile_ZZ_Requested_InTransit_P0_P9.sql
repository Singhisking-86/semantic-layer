/* #### ARCHIVED — SUPERSEDED. DO NOT RUN. ####
   First profiling draft with <PLACEHOLDER> column names (P0 = schema probe).
   Replaced by ../answered/Profile_ZZ_Tables_FINAL_P1_P14.sql (real columns).
   Legacy P1–P9 here = register RET-GRAIN-*/RET-TRANSIT-*/RET-XTABLE-01.
   Kept for provenance only. See ../REGISTER.md and ./_WHY_ARCHIVED.md.
   ############################################ */

/* ============================================================
   PROFILE: PRODVM.ZZ_RETURN_REQUESTED & PRODVM.ZZ_RETURN_IN_TRANSIT
   Source of truth = confirmed discovery results only.
   Confirmed columns used: ReturnID, SKU, TrackingID,
   datetimerequested, ReturnReason | RETURNID, TRACKINGID,
   DATETIMEINTRANSIT, LASTTRACKINGSTATUS.
   <ORDER_NO_COL> / <ORDER_LINE_COL> -> fill from P0 output.
   Windows = 150 days. Run one statement at a time, export CSVs.
   ============================================================ */

/* ---------- P0 · ACTUAL SCHEMA of both tables (run FIRST).
   Production base rows supply types where PRODVM view rows are NULL. */
SEL c.DatabaseName, c.TableName, c.ColumnId, c.ColumnName,
    c.ColumnType, c.ColumnLength, c.Nullable
FROM DBC.ColumnsV c
WHERE (c.DatabaseName = 'PRODVM'     AND c.TableName = 'ZZ_RETURN_REQUESTED')
   OR (c.DatabaseName = 'PRODVM'     AND c.TableName = 'ZZ_RETURN_IN_TRANSIT')
   OR (c.DatabaseName = 'Production' AND c.TableName = 'ZZ_RETURN_REQUESTED')
   OR (c.DatabaseName = 'Production' AND c.TableName = 'ZZ_RETURN_IN_TRANSIT')
ORDER BY c.DatabaseName, c.TableName, c.ColumnId;


/* ============ ZZ_RETURN_REQUESTED — grain validation ============ */

/* ---------- P1 · Key-uniqueness ladder ---------- */
SEL COUNT(*) AS rows_,
    COUNT(DISTINCT ReturnID) AS returns_,
    COUNT(DISTINCT ReturnID || '|' || SKU) AS return_sku,
    COUNT(DISTINCT ReturnID || '|' || TRIM(<ORDER_NO_COL>) || '|' || TRIM(<ORDER_LINE_COL>)) AS return_order_line,
    SUM(CASE WHEN <ORDER_NO_COL> IS NULL OR <ORDER_LINE_COL> IS NULL THEN 1 ELSE 0 END) AS null_order_keys,
    SUM(CASE WHEN SKU IS NULL THEN 1 ELSE 0 END) AS null_sku,
    SUM(CASE WHEN TrackingID IS NULL THEN 1 ELSE 0 END) AS null_tracking
FROM PRODVM.ZZ_RETURN_REQUESTED
WHERE datetimerequested GE DATE - 150;
/* Grain confirmed if return_order_line = rows_. */

/* ---------- P2 · Lines per return distribution ---------- */
SEL lines_per_return, COUNT(*) AS returns_
FROM (SEL ReturnID, COUNT(*) AS lines_per_return
      FROM PRODVM.ZZ_RETURN_REQUESTED
      WHERE datetimerequested GE DATE - 150
      GROUP BY 1) x
GROUP BY 1 ORDER BY 1;

/* ---------- P3 · Repeated (ReturnID, SKU): qty rows or distinct order lines? ---------- */
SEL CASE WHEN distinct_order_lines = dup_rows THEN 'different order lines'
         WHEN distinct_order_lines = 1        THEN 'same line repeated'
         ELSE 'mixed' END AS explanation,
    COUNT(*) AS return_sku_pairs,
    SUM(dup_rows) AS rows_involved
FROM (SEL ReturnID, SKU, COUNT(*) AS dup_rows,
          COUNT(DISTINCT TRIM(<ORDER_NO_COL>) || '|' || TRIM(<ORDER_LINE_COL>)) AS distinct_order_lines
      FROM PRODVM.ZZ_RETURN_REQUESTED
      WHERE datetimerequested GE DATE - 150
      GROUP BY 1,2
      HAVING COUNT(*) > 1) x
GROUP BY 1;

/* ---------- P4 · Re-requests: one order line under multiple ReturnIDs? ---------- */
SEL returns_per_order_line, COUNT(*) AS order_lines
FROM (SEL TRIM(<ORDER_NO_COL>) || '|' || TRIM(<ORDER_LINE_COL>) AS order_line_key,
          COUNT(DISTINCT ReturnID) AS returns_per_order_line
      FROM PRODVM.ZZ_RETURN_REQUESTED
      WHERE datetimerequested GE DATE - 150
        AND <ORDER_NO_COL> IS NOT NULL
      GROUP BY 1) x
GROUP BY 1 ORDER BY 1;

/* ---------- P5 · TrackingID 1:1 with ReturnID? ---------- */
SEL trackings_per_return, COUNT(*) AS returns_
FROM (SEL ReturnID, COUNT(DISTINCT TrackingID) AS trackings_per_return
      FROM PRODVM.ZZ_RETURN_REQUESTED
      WHERE datetimerequested GE DATE - 150
      GROUP BY 1) x
GROUP BY 1 ORDER BY 1;


/* ============ ZZ_RETURN_IN_TRANSIT — structure validation ============ */

/* ---------- P6 · Row counts, key cardinality, duplicate check ---------- */
SEL COUNT(*) AS rows_,
    COUNT(DISTINCT RETURNID) AS returns_,
    COUNT(DISTINCT TRACKINGID) AS trackings_,
    COUNT(*) - COUNT(DISTINCT RETURNID || '|' || CAST(DATETIMEINTRANSIT AS VARCHAR(26))) AS dup_return_ts_rows
FROM PRODVM.ZZ_RETURN_IN_TRANSIT
WHERE DATETIMEINTRANSIT GE DATE - 150;

/* ---------- P7 · Events per return: milestone log (≤2) or longer history? ---------- */
SEL events_per_return, COUNT(*) AS returns_
FROM (SEL RETURNID, COUNT(*) AS events_per_return
      FROM PRODVM.ZZ_RETURN_IN_TRANSIT
      WHERE DATETIMEINTRANSIT GE DATE - 150
      GROUP BY 1) x
GROUP BY 1 ORDER BY 1;

/* ---------- P8 · Semantics of row 1 vs row 2 (status class by rank) ---------- */
SEL row_rank,
    CASE WHEN LASTTRACKINGSTATUS LIKE '%Delivered to Retailer%'
           OR LASTTRACKINGSTATUS LIKE '%DeliveredToRetailer%' THEN 'DELIVERED'
         WHEN LASTTRACKINGSTATUS LIKE '%In Transit%'
           OR LASTTRACKINGSTATUS LIKE '%InTransit%'           THEN 'IN_TRANSIT'
         WHEN LASTTRACKINGSTATUS LIKE '%Dropped off%'
           OR LASTTRACKINGSTATUS LIKE '%DroppedOff%'          THEN 'DROPPED_OFF'
         ELSE 'OTHER' END AS status_class,
    COUNT(*) AS rows_
FROM (SEL RETURNID, LASTTRACKINGSTATUS,
          ROW_NUMBER() OVER (PARTITION BY RETURNID ORDER BY DATETIMEINTRANSIT) AS row_rank
      FROM PRODVM.ZZ_RETURN_IN_TRANSIT
      WHERE DATETIMEINTRANSIT GE DATE - 150) x
GROUP BY 1,2 ORDER BY 1,3 DESC;


/* ============ CROSS-TABLE consistency ============ */

/* ---------- P9 · Same ReturnID & TrackingID across both tables? ---------- */
SEL COUNT(DISTINCT r.ReturnID) AS returns_150d,
    COUNT(DISTINCT t.RETURNID) AS with_transit_rows,
    SUM(CASE WHEN t.RETURNID IS NOT NULL
              AND r.TrackingID <> t.TRACKINGID THEN 1 ELSE 0 END) AS tracking_mismatch_lines
FROM PRODVM.ZZ_RETURN_REQUESTED r
LEFT JOIN (SEL DISTINCT RETURNID, TRACKINGID
           FROM PRODVM.ZZ_RETURN_IN_TRANSIT
           WHERE DATETIMEINTRANSIT GE DATE - 150) t
       ON r.ReturnID = t.RETURNID
WHERE r.datetimerequested GE DATE - 150;

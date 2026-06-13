/* #### ARCHIVED — SUPERSEDED. DO NOT RUN. ####
   Early grain probes with GUESSED column names. Re-run correctly as the
   P-series → register IDs: Q20→RET-GRAIN-01, Q21→RET-GRAIN-03,
   Q22→RET-TRANSIT-02, Q23→RET-TRANSIT-03, Q24→RET-GRAIN-04.
   Canonical SQL: ../answered/Profile_ZZ_Tables_FINAL_P1_P14.sql.
   Kept for provenance only. See ../REGISTER.md and ./_WHY_ARCHIVED.md.
   ############################################ */

/* ============================================================
   GRAIN VALIDATION — ZZ_RETURN_REQUESTED & ZZ_RETURN_IN_TRANSIT
   Q20–Q24 · 150-day windows · run one at a time, export CSVs.
   NOTE: Q20/Q21/Q24 assume the order columns are named
   OrderNumber / OrderItemNumber. If Q8 (HELP TABLE) shows
   different names, substitute before running.
   ============================================================ */

/* ---------- Q20 · REQUESTED raw grain: which key is unique? ---------- */
SEL COUNT(*) AS rows_,
    COUNT(DISTINCT ReturnID) AS returns_,
    COUNT(DISTINCT ReturnID || '|' || SKU) AS return_sku,
    COUNT(DISTINCT ReturnID || '|' || TRIM(OrderNumber) || '|' || TRIM(OrderItemNumber)) AS return_order_line,
    SUM(CASE WHEN OrderNumber IS NULL OR OrderItemNumber IS NULL THEN 1 ELSE 0 END) AS null_order_keys,
    SUM(CASE WHEN SKU IS NULL THEN 1 ELSE 0 END) AS null_sku
FROM PRODVM.ZZ_RETURN_REQUESTED
WHERE datetimerequested GE DATE - 150;
/* If return_order_line = rows_, grain = (ReturnID, OrderNumber, OrderItemNumber). */


/* ---------- Q21 · Repeated (ReturnID, SKU): qty rows or different order lines? ---------- */
SEL CASE WHEN distinct_order_lines = dup_rows THEN 'different order lines'
         WHEN distinct_order_lines = 1        THEN 'same line repeated (qty?)'
         ELSE 'mixed' END AS explanation,
    COUNT(*) AS affected_return_sku_pairs,
    SUM(dup_rows) AS affected_rows
FROM (
    SEL ReturnID, SKU,
        COUNT(*) AS dup_rows,
        COUNT(DISTINCT TRIM(OrderNumber) || '|' || TRIM(OrderItemNumber)) AS distinct_order_lines
    FROM PRODVM.ZZ_RETURN_REQUESTED
    WHERE datetimerequested GE DATE - 150
    GROUP BY 1,2
    HAVING COUNT(*) > 1
) x
GROUP BY 1;


/* ---------- Q22 · IN_TRANSIT structure on 150d: confirm ≤2-row milestone log ---------- */
SEL events_per_return, COUNT(*) AS returns_
FROM (
    SEL RETURNID, COUNT(*) AS events_per_return
    FROM PRODVM.ZZ_RETURN_IN_TRANSIT
    WHERE DATETIMEINTRANSIT GE DATE - 150
    GROUP BY 1
) x
GROUP BY 1 ORDER BY 1;
/* Expect only 1 and 2. Any 3+ on the wider window changes the L1 load rule. */


/* ---------- Q23 · Row-class semantics: first vs second row status mix ---------- */
SEL row_rank,
    CASE WHEN LASTTRACKINGSTATUS LIKE '%Delivered to Retailer%'
           OR LASTTRACKINGSTATUS LIKE '%DeliveredToRetailer%' THEN 'DELIVERED'
         WHEN LASTTRACKINGSTATUS LIKE '%In Transit%'
           OR LASTTRACKINGSTATUS LIKE '%InTransit%'           THEN 'IN_TRANSIT'
         WHEN LASTTRACKINGSTATUS LIKE '%Dropped off%'
           OR LASTTRACKINGSTATUS LIKE '%DroppedOff%'          THEN 'DROPPED_OFF'
         ELSE 'OTHER' END AS status_class,
    COUNT(*) AS rows_
FROM (
    SEL RETURNID, LASTTRACKINGSTATUS,
        ROW_NUMBER() OVER (PARTITION BY RETURNID ORDER BY DATETIMEINTRANSIT) AS row_rank
    FROM PRODVM.ZZ_RETURN_IN_TRANSIT
    WHERE DATETIMEINTRANSIT GE DATE - 150
) x
GROUP BY 1,2 ORDER BY 1,3 DESC;


/* ---------- Q24 · Re-requests: can one order line appear in >1 ReturnID? ---------- */
SEL returns_per_order_line, COUNT(*) AS order_lines
FROM (
    SEL TRIM(OrderNumber) || '|' || TRIM(OrderItemNumber) AS order_line_key,
        COUNT(DISTINCT ReturnID) AS returns_per_order_line
    FROM PRODVM.ZZ_RETURN_REQUESTED
    WHERE datetimerequested GE DATE - 150
      AND OrderNumber IS NOT NULL
    GROUP BY 1
) x
GROUP BY 1 ORDER BY 1;
/* >1 means re-requests exist -> L1 needs a request-attempt concept
   and the Return Rate join (orderline -> return) can multi-match. */

/* ============================================================
   ANSWERED — verdicts in ../../docs/03_profiling_findings.md.
   Canonical IDs below (legacy P-numbers in parentheses); see ../REGISTER.md.
   PROFILE (FINAL) — PRODVM.ZZ_RETURN_REQUESTED & ZZ_RETURN_IN_TRANSIT
   Column names taken from the uploaded catalog (db_table_column_name.csv).
   ZZ_RETURN_REQUESTED (22 cols): ORDERNUMBER, ORDERLINEITEMNUMBER,
     CUSTOMERID, RETAILER, RETURNID, CARRIER, CARRIERSERVICE,
     EXTERNALREFERENCE, SKU, DATETIMEREQUESTED, RETURNREASON,
     RETURNCOST, WAREHOUSEREFERENCE, TRACKINGID, LASTTRACKINGSTATUS,
     ORDERSTATUS, RETURNOPTION, NOTES, NOTESCONTENT, VOUCHERVALUE,
     INSERTED_ON, UPDATED_ON
   ZZ_RETURN_IN_TRANSIT (4 cols): RETURNID, DATETIMEINTRANSIT,
     TRACKINGID, LASTTRACKINGSTATUS
   Windows = 150 days. Run one statement at a time, export CSVs.
   ============================================================ */

/* ============ ZZ_RETURN_REQUESTED — grain ============ */

/* ---------- RET-GRAIN-01 (legacy P1) · Key-uniqueness ladder ---------- */
SEL COUNT(*) AS rows_,
    COUNT(DISTINCT RETURNID) AS returns_,
    COUNT(DISTINCT RETURNID || '|' || SKU) AS return_sku,
    COUNT(DISTINCT RETURNID || '|' || TRIM(ORDERNUMBER) || '|' || TRIM(ORDERLINEITEMNUMBER)) AS return_order_line,
    SUM(CASE WHEN ORDERNUMBER IS NULL OR ORDERLINEITEMNUMBER IS NULL THEN 1 ELSE 0 END) AS null_order_keys,
    SUM(CASE WHEN SKU IS NULL THEN 1 ELSE 0 END) AS null_sku,
    SUM(CASE WHEN TRACKINGID IS NULL THEN 1 ELSE 0 END) AS null_tracking
FROM PRODVM.ZZ_RETURN_REQUESTED
WHERE DATETIMEREQUESTED GE DATE - 150;
/* Grain confirmed if return_order_line = rows_. */

/* ---------- RET-GRAIN-02 (legacy P2) · Lines per return distribution ---------- */
SEL lines_per_return, COUNT(*) AS returns_
FROM (SEL RETURNID, COUNT(*) AS lines_per_return
      FROM PRODVM.ZZ_RETURN_REQUESTED
      WHERE DATETIMEREQUESTED GE DATE - 150
      GROUP BY 1) x
GROUP BY 1 ORDER BY 1;

/* ---------- RET-GRAIN-03 (legacy P3) · Repeated (RETURNID, SKU): distinct order lines? ---------- */
SEL CASE WHEN distinct_order_lines = dup_rows THEN 'different order lines'
         WHEN distinct_order_lines = 1        THEN 'same line repeated'
         ELSE 'mixed' END AS explanation,
    COUNT(*) AS return_sku_pairs,
    SUM(dup_rows) AS rows_involved
FROM (SEL RETURNID, SKU, COUNT(*) AS dup_rows,
          COUNT(DISTINCT TRIM(ORDERNUMBER) || '|' || TRIM(ORDERLINEITEMNUMBER)) AS distinct_order_lines
      FROM PRODVM.ZZ_RETURN_REQUESTED
      WHERE DATETIMEREQUESTED GE DATE - 150
      GROUP BY 1,2
      HAVING COUNT(*) > 1) x
GROUP BY 1;

/* ---------- RET-GRAIN-04 (legacy P4) · Re-requests: one order line under >1 RETURNID? ---------- */
SEL returns_per_order_line, COUNT(*) AS order_lines
FROM (SEL TRIM(ORDERNUMBER) || '|' || TRIM(ORDERLINEITEMNUMBER) AS order_line_key,
          COUNT(DISTINCT RETURNID) AS returns_per_order_line
      FROM PRODVM.ZZ_RETURN_REQUESTED
      WHERE DATETIMEREQUESTED GE DATE - 150
        AND ORDERNUMBER IS NOT NULL
      GROUP BY 1) x
GROUP BY 1 ORDER BY 1;

/* ---------- RET-TRANSIT-01 (legacy P5) · TRACKINGID 1:1 with RETURNID? ---------- */
SEL trackings_per_return, COUNT(*) AS returns_
FROM (SEL RETURNID, COUNT(DISTINCT TRACKINGID) AS trackings_per_return
      FROM PRODVM.ZZ_RETURN_REQUESTED
      WHERE DATETIMEREQUESTED GE DATE - 150
      GROUP BY 1) x
GROUP BY 1 ORDER BY 1;


/* ============ NEW COLUMNS the PBIX never used ============ */

/* ---------- RET-COL-01 (legacy P10) · RETURNOPTION = return method? (Royal Mail /
   Parcelshop / Evri collection) from the flow diagram? ---------- */
SEL RETURNOPTION, COUNT(*) AS lines_, COUNT(DISTINCT RETURNID) AS returns_
FROM PRODVM.ZZ_RETURN_REQUESTED
WHERE DATETIMEREQUESTED GE DATE - 150
GROUP BY 1 ORDER BY 2 DESC;

/* ---------- RET-CDC-01 (legacy P11) · CDC INSERTED_ON lag vs request time.
   Decides incremental-load watermark + achievable freshness. ---------- */
SEL CAST((INSERTED_ON - DATETIMEREQUESTED) DAY(4) TO SECOND AS VARCHAR(30)) AS lag_sample,
    COUNT(*) AS rows_
FROM PRODVM.ZZ_RETURN_REQUESTED
WHERE DATETIMEREQUESTED GE DATE - 7
GROUP BY 1 ORDER BY 2 DESC;
/* If interval grouping is awkward, simpler version: */
SEL AVG(CAST(INSERTED_ON AS DATE) - CAST(DATETIMEREQUESTED AS DATE)) AS avg_lag_days,
    MAX(INSERTED_ON) AS latest_insert,
    SUM(CASE WHEN UPDATED_ON > INSERTED_ON THEN 1 ELSE 0 END) AS rows_updated_after_insert
FROM PRODVM.ZZ_RETURN_REQUESTED
WHERE DATETIMEREQUESTED GE DATE - 150;

/* ---------- RET-COL-02 (legacy P12) · Channel & value signals: fill rates ---------- */
SEL COUNT(*) AS rows_,
    SUM(CASE WHEN NOTES IS NOT NULL AND TRIM(NOTES) <> '' THEN 1 ELSE 0 END) AS with_notes,
    SUM(CASE WHEN RETURNCOST IS NOT NULL THEN 1 ELSE 0 END) AS with_returncost,
    SUM(CASE WHEN VOUCHERVALUE IS NOT NULL THEN 1 ELSE 0 END) AS with_vouchervalue,
    SUM(CASE WHEN EXTERNALREFERENCE IS NOT NULL THEN 1 ELSE 0 END) AS with_extref,
    SUM(CASE WHEN WAREHOUSEREFERENCE IS NOT NULL THEN 1 ELSE 0 END) AS with_whref,
    COUNT(DISTINCT ORDERSTATUS) AS distinct_orderstatus,
    COUNT(DISTINCT RETAILER) AS distinct_retailers
FROM PRODVM.ZZ_RETURN_REQUESTED
WHERE DATETIMEREQUESTED GE DATE - 150;


/* ============ ZZ_RETURN_IN_TRANSIT — structure ============ */

/* ---------- RET-TRANSIT-02 (legacy P6) · Cardinality & duplicates ---------- */
SEL COUNT(*) AS rows_,
    COUNT(DISTINCT RETURNID) AS returns_,
    COUNT(DISTINCT TRACKINGID) AS trackings_,
    COUNT(*) - COUNT(DISTINCT RETURNID || '|' || CAST(DATETIMEINTRANSIT AS VARCHAR(26))) AS dup_return_ts_rows
FROM PRODVM.ZZ_RETURN_IN_TRANSIT
WHERE DATETIMEINTRANSIT GE DATE - 150;

/* ---------- RET-TRANSIT-03 (legacy P7) · Events per return (milestone log?) ---------- */
SEL events_per_return, COUNT(*) AS returns_
FROM (SEL RETURNID, COUNT(*) AS events_per_return
      FROM PRODVM.ZZ_RETURN_IN_TRANSIT
      WHERE DATETIMEINTRANSIT GE DATE - 150
      GROUP BY 1) x
GROUP BY 1 ORDER BY 1;

/* ---------- RET-TRANSIT-03 (legacy P8) · Row-1 vs row-2 semantics ---------- */
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

/* ---------- RET-XTABLE-01 (legacy P9) · Cross-table key consistency ---------- */
SEL COUNT(DISTINCT r.RETURNID) AS returns_150d,
    COUNT(DISTINCT t.RETURNID) AS with_transit_rows,
    SUM(CASE WHEN t.RETURNID IS NOT NULL
              AND r.TRACKINGID <> t.TRACKINGID THEN 1 ELSE 0 END) AS tracking_mismatch_lines
FROM PRODVM.ZZ_RETURN_REQUESTED r
LEFT JOIN (SEL DISTINCT RETURNID, TRACKINGID
           FROM PRODVM.ZZ_RETURN_IN_TRANSIT
           WHERE DATETIMEINTRANSIT GE DATE - 150) t
       ON r.RETURNID = t.RETURNID
WHERE r.DATETIMEREQUESTED GE DATE - 150;


/* ============ BRIDGE TO THE NEWLY DISCOVERED WMS/REFUND MODEL ============ */

/* ---------- REF-BRIDGE-01 (legacy P13) · Can ZZ requests link to PRODVM.RETURN_ITEM?
   RETURN_ITEM keys: ORDER_SERIAL_NUMBER + ORDERLINE_NUMBER (+account/trading).
   Tests the bridge ZZ ORDERNUMBER/ORDERLINEITEMNUMBER -> WMS item record. ---------- */
SEL COUNT(*) AS zz_lines_150d,
    SUM(CASE WHEN ri.ORDER_SERIAL_NUMBER IS NOT NULL THEN 1 ELSE 0 END) AS matched_to_return_item,
    SUM(CASE WHEN ri.CUSTOMER_CREDITED_IND = 'Y' THEN 1 ELSE 0 END) AS matched_and_credited
FROM PRODVM.ZZ_RETURN_REQUESTED r
LEFT JOIN PRODVM.RETURN_ITEM ri
       ON  TRIM(r.ORDERNUMBER)        = TRIM(ri.ORDER_SERIAL_NUMBER)
       AND TRIM(r.ORDERLINEITEMNUMBER) = TRIM(ri.ORDERLINE_NUMBER)
WHERE r.DATETIMEREQUESTED GE DATE - 150;
/* If match rate is low, retry with account/trading in the key or via
   warehousedb-style numeric casts; report what you see. */

/* ---------- REF-SIGNAL-01 (legacy P14) · Refund answerability (D6): CUSTOMER_CREDITED_IND
   coverage and the WH event vocabulary that marks crediting ---------- */
SEL CUSTOMER_CREDITED_IND, COUNT(*) AS items_
FROM PRODVM.RETURN_ITEM
WHERE RETURN_DATE GE DATE - 150
GROUP BY 1;

SEL EVENT_CODE, COUNT(*) AS events_,
    SUM(CASE WHEN CUSTOMER_CREDITED_IND = 'Y' THEN 1 ELSE 0 END) AS credited_rows
FROM PRODVM.RETURN_ITEM_EVENT_HISTORY
WHERE EVENT_DATE GE DATE - 150
GROUP BY 1 ORDER BY 2 DESC;

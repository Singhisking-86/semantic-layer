/* ============================================================
   N BROWN RETURNS — PHASE 1 VALIDATION (REVISED: no warehousedb)
   Canonical IDs: see ../REGISTER.md. Legacy Q-numbers kept in
   parentheses for provenance. Statements carry @name = register ID
   so scripts/run_sql.py writes CSVs as <ID>_<suffix>.csv.
   Legacy Q1–Q5 = MART-01..05 (done offline). Q6/Q13 = DEAD (warehousedb).
   Windows = 150 days (D4). Run one statement at a time.
   ============================================================ */


/* @name RET-REASON-01_taxonomy
   RET-REASON-01 (legacy Q7) · REASON TAXONOMY + volume, 150d */
SEL ReturnReason, COUNT(*) AS requests
FROM PRODVM.ZZ_RETURN_REQUESTED
WHERE datetimerequested GE DATE - 150
GROUP BY 1
ORDER BY 2 DESC;


/* @name RET-SCHEMA-01_request_columns
   RET-SCHEMA-01 (legacy Q8) · COLUMNS of the request source */
HELP TABLE PRODVM.ZZ_RETURN_REQUESTED;


/* @name RET-HIST-01_depth
   RET-HIST-01 (legacy Q9) · HISTORY DEPTH per source */
SEL 'ZZ_RETURN_REQUESTED' AS src, MIN(CAST(datetimerequested AS DATE)) AS earliest,
       MAX(CAST(datetimerequested AS DATE)) AS latest, COUNT(*) AS rows_
FROM PRODVM.ZZ_RETURN_REQUESTED
UNION ALL
SEL 'ZZ_RETURN_IN_TRANSIT', MIN(CAST(DATETIMEINTRANSIT AS DATE)),
       MAX(CAST(DATETIMEINTRANSIT AS DATE)), COUNT(*)
FROM PRODVM.ZZ_RETURN_IN_TRANSIT
UNION ALL
SEL 'HERMES_TRACKING', MIN(CAST(date_and_time_of_event AS DATE)),
       MAX(CAST(date_and_time_of_event AS DATE)), COUNT(*)
FROM PRODVM.HERMES_RETURN_TRACKING_DETAIL;


/* @name RET-FRESH-01_request
   RET-FRESH-01 (legacy Q10) · FRESHNESS: latest event per source */
SEL MAX(datetimerequested)      AS latest_request   FROM PRODVM.ZZ_RETURN_REQUESTED;
/* @name RET-FRESH-01_zz_scan */
SEL MAX(DATETIMEINTRANSIT)      AS latest_zz_scan   FROM PRODVM.ZZ_RETURN_IN_TRANSIT;
/* @name RET-FRESH-01_evri_scan */
SEL MAX(date_and_time_of_event) AS latest_evri_scan FROM PRODVM.HERMES_RETURN_TRACKING_DETAIL;


/* @name REF-DISCOVERY-01_source_sweep
   REF-DISCOVERY-01 (legacy Q11) · REFUND/PAYMENT SOURCE DISCOVERY */
SEL DatabaseName, TableName, TableKind
FROM DBC.TablesV
WHERE (   LOWER(TableName) LIKE '%refund%'
       OR LOWER(TableName) LIKE '%payment%'
       OR LOWER(TableName) LIKE '%credit%adjust%'
       OR LOWER(TableName) LIKE '%transaction%'
       OR LOWER(TableName) LIKE '%remittance%')
  AND LOWER(DatabaseName) NOT LIKE 'devt%'
  AND LOWER(DatabaseName) NOT LIKE 'uk1_%'
  AND LOWER(DatabaseName) NOT IN ('sampledb','suppdb')
ORDER BY DatabaseName, TableName;


/* @name RET-NRT-01_prodvm_vs_upd
   RET-NRT-01 (legacy Q12) · PRODVM vs PRODVMUPD freshness (NRT sizing) */
SEL 'PRODVM'    AS layer, MAX(datetimerequested) AS latest_request
FROM PRODVM.ZZ_RETURN_REQUESTED
UNION ALL
SEL 'PRODVMUPD', MAX(datetimerequested)
FROM PRODVMUPD.ZZ_RETURN_REQUESTED;


/* @name RET-PAYMENT-01_orderline_columns
   RET-PAYMENT-01 (legacy Q14) · PAYMENT-METHOD SIGNAL in orderline */
HELP TABLE PRODUCTION_ORDERLINE.orderline_current;


/* ============================================================
   NEW · STATE RECONSTRUCTION FROM RAW EVENTS
   ============================================================ */

/* RET-KEYMAP-01 (legacy Q15) · KEY MAP: how requests link to each event
   stream. ZZ keys on RETURNID; EVRI on barcode = TrackingID. Coverage 150d. */
/* @name RET-KEYMAP-01_stream_coverage */
SEL COUNT(*) AS requests_150d,
    SUM(CASE WHEN z.RETURNID  IS NOT NULL THEN 1 ELSE 0 END) AS with_zz_events,
    SUM(CASE WHEN h.barcode   IS NOT NULL THEN 1 ELSE 0 END) AS with_evri_events,
    SUM(CASE WHEN z.RETURNID IS NOT NULL AND h.barcode IS NOT NULL THEN 1 ELSE 0 END) AS with_both,
    SUM(CASE WHEN z.RETURNID IS NULL AND h.barcode IS NULL THEN 1 ELSE 0 END) AS with_neither
FROM PRODVM.ZZ_RETURN_REQUESTED r
LEFT JOIN (SEL DISTINCT RETURNID FROM PRODVM.ZZ_RETURN_IN_TRANSIT
           WHERE DATETIMEINTRANSIT GE DATE - 150) z
       ON r.ReturnID = z.RETURNID
LEFT JOIN (SEL DISTINCT hermes_barcode AS barcode FROM PRODVM.HERMES_RETURN_TRACKING_DETAIL
           WHERE date_and_time_of_event GE DATE - 150) h
       ON r.TrackingID = h.barcode
WHERE r.datetimerequested GE DATE - 150;


/* @name RET-STATE-01_state2_coverage
   RET-STATE-01 (legacy Q16) · STATE ② first-carrier-scan coverage & lag */
SEL COUNT(*) AS requests,
    SUM(CASE WHEN f.first_scan IS NOT NULL THEN 1 ELSE 0 END) AS reached_state2,
    AVG(CAST(f.first_scan AS DATE) - CAST(r.datetimerequested AS DATE)) AS avg_leg1_days
FROM PRODVM.ZZ_RETURN_REQUESTED r
LEFT JOIN (SEL RETURNID, MIN(DATETIMEINTRANSIT) AS first_scan
           FROM PRODVM.ZZ_RETURN_IN_TRANSIT
           WHERE DATETIMEINTRANSIT GE DATE - 150
           GROUP BY 1) f
       ON r.ReturnID = f.RETURNID
WHERE r.datetimerequested GE DATE - 150
  AND r.datetimerequested LE DATE - 30;   /* mature cohort: 30d+ old */


/* RET-STATE-02 (legacy Q17) · STATE ④ WH-processed coverage from each signal */
/* @name RET-STATE-02_state4_via_evri_p394
   17a: EVRI P394 'RETURNED TO WAREHOUSE' */
SEL COUNT(DISTINCT r.ReturnID) AS mature_requests,
    COUNT(DISTINCT CASE WHEN p.barcode IS NOT NULL THEN r.ReturnID END) AS with_evri_p394
FROM PRODVM.ZZ_RETURN_REQUESTED r
LEFT JOIN (SEL hermes_barcode AS barcode, MIN(date_and_time_of_event) AS wh_scan
           FROM PRODVM.HERMES_RETURN_TRACKING_DETAIL
           WHERE jdw_event_code = 'P394'
             AND date_and_time_of_event GE DATE - 150
           GROUP BY 1) p
       ON r.TrackingID = p.barcode
WHERE r.datetimerequested GE DATE - 150
  AND r.datetimerequested LE DATE - 30;

/* @name RET-STATE-02_state4_via_zz_delivered
   17b: ZZ 'Delivered to Retailer' statuses */
SEL COUNT(DISTINCT r.ReturnID) AS mature_requests,
    COUNT(DISTINCT CASE WHEN d.RETURNID IS NOT NULL THEN r.ReturnID END) AS with_zz_delivered
FROM PRODVM.ZZ_RETURN_REQUESTED r
LEFT JOIN (SEL RETURNID, MIN(DATETIMEINTRANSIT) AS delivered_ts
           FROM PRODVM.ZZ_RETURN_IN_TRANSIT
           WHERE LASTTRACKINGSTATUS LIKE '%Delivered to Retailer%'
             AND DATETIMEINTRANSIT GE DATE - 150
           GROUP BY 1) d
       ON r.ReturnID = d.RETURNID
WHERE r.datetimerequested GE DATE - 150
  AND r.datetimerequested LE DATE - 30;


/* REF-EVENTVOCAB-FULL (legacy Q18) · FULL event vocabulary on live 150d
   (confirms the 90d PBIX-copy profile + volumes) for the L1 state map. */
/* @name REF-EVENTVOCAB-FULL_zz_status */
SEL LASTTRACKINGSTATUS, COUNT(*) AS events, COUNT(DISTINCT RETURNID) AS returns_
FROM PRODVM.ZZ_RETURN_IN_TRANSIT
WHERE DATETIMEINTRANSIT GE DATE - 150
GROUP BY 1 ORDER BY 2 DESC;

/* @name REF-EVENTVOCAB-FULL_evri_codes */
SEL t1.jdw_event_code, t2.despatch_event_desc,
    COUNT(*) AS events, COUNT(DISTINCT t1.hermes_barcode) AS parcels
FROM PRODVM.HERMES_RETURN_TRACKING_DETAIL t1
LEFT JOIN PRODVM.despatch_event_code t2
       ON t1.jdw_event_code = t2.despatch_event_code
WHERE t1.date_and_time_of_event GE DATE - 150
GROUP BY 1,2 ORDER BY 3 DESC;


/* @name RET-STATE-03_reconstruction_parity
   RET-STATE-03 (legacy Q19) · RECONSTRUCTION PARITY — daily state counts from
   events, compared to the PBIX snapshot benchmark. PHASE-1 EXIT GATE. */
SEL CAST(r.datetimerequested AS DATE) AS request_date,
    COUNT(*) AS requested,
    SUM(CASE WHEN f.first_scan IS NOT NULL THEN 1 ELSE 0 END) AS reached_carrier,
    SUM(CASE WHEN w.wh_ts IS NOT NULL THEN 1 ELSE 0 END) AS reached_wh,
    SUM(CASE WHEN w.wh_ts IS NOT NULL
              AND (CAST(w.wh_ts AS DATE) - CAST(f.first_scan AS DATE)) <= 10
             THEN 1 ELSE 0 END) AS in_10day_sla
FROM PRODVM.ZZ_RETURN_REQUESTED r
LEFT JOIN (SEL RETURNID, MIN(DATETIMEINTRANSIT) AS first_scan
           FROM PRODVM.ZZ_RETURN_IN_TRANSIT
           WHERE DATETIMEINTRANSIT GE DATE - 150 GROUP BY 1) f
       ON r.ReturnID = f.RETURNID
LEFT JOIN (SEL RETURNID, MIN(DATETIMEINTRANSIT) AS wh_ts
           FROM PRODVM.ZZ_RETURN_IN_TRANSIT
           WHERE LASTTRACKINGSTATUS LIKE '%Delivered to Retailer%'
             AND DATETIMEINTRANSIT GE DATE - 150 GROUP BY 1) w
       ON r.ReturnID = w.RETURNID
WHERE r.datetimerequested GE DATE - 120
  AND r.datetimerequested LE DATE - 30
GROUP BY 1 ORDER BY 1;

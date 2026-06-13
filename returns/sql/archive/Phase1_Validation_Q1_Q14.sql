/* #### ARCHIVED — SUPERSEDED. DO NOT RUN. ####
   Superseded by ../open/Phase1_Validation_Revised_No_Warehousedb.sql.
   Legacy Q1–Q5 = MART-01..05 (done offline). Q6/Q13 = DEAD (warehousedb).
   Q7–Q14 live on under register IDs in the revised file. See ../REGISTER.md
   and ./_WHY_ARCHIVED.md. Kept for provenance only.
   ############################################ */

/* ============================================================
   N BROWN RETURNS — SEMANTIC LAYER PHASE 1 VALIDATION
   Queries Q1–Q14 · run in Teradata SQL editor · export each
   result to CSV and upload. All windows = 150 days (D4).
   ============================================================ */

/* ---------- Q1 · GRAIN: is MB_ZZ_parcels one row per return? ---------- */
SEL COUNT(*)                    AS rows_total,
    COUNT(DISTINCT RETURNID)    AS distinct_returns,
    COUNT(DISTINCT TRACKINGID)  AS distinct_tracking
FROM warehousedb.MB_ZZ_parcels;


/* ---------- Q2 · STATE ORDERING: violations of ① ≤ ② ≤ ③ ≤ ④ ---------- */
SEL SUM(CASE WHEN Start_Carrier_Journey < DateReturnRequested  THEN 1 ELSE 0 END) AS scan_before_request,
    SUM(CASE WHEN End_Carrier_Journey   < Start_Carrier_Journey THEN 1 ELSE 0 END) AS handover_before_scan,
    SUM(CASE WHEN DateReturnedWH        < End_Carrier_Journey   THEN 1 ELSE 0 END) AS wh_before_handover,
    SUM(CASE WHEN DateReturnedWH IS NOT NULL
              AND Start_Carrier_Journey IS NULL                 THEN 1 ELSE 0 END) AS processed_no_carrier_scan,
    COUNT(*) AS total_rows
FROM warehousedb.MB_ZZ_parcels;


/* ---------- Q3 · FLAG ARITHMETIC: do 4 statuses partition requests? ---------- */
SEL SUM(ReturnsRequested)      AS requested,
    SUM(IdleReturnRequests)    AS idle,
    SUM(ParcelsInTransit)      AS in_transit,
    SUM(Parcels_at_WH_WIP)     AS wh_wip,
    SUM(ParcelsProcessedByWH)  AS processed,
    SUM(IdleReturnRequests) + SUM(ParcelsInTransit)
      + SUM(Parcels_at_WH_WIP) + SUM(ParcelsProcessedByWH) AS sum_of_states
FROM warehousedb.MB_ZZ_parcels;


/* ---------- Q4 · SLA RECONSTRUCTION: which date starts the 10-day clock? ---------- */
SEL SUM(Returned_in_10_SLA)         AS flag_in_sla,
    SUM(CASE WHEN DateReturnedWH - Start_Carrier_Journey <= 10
              AND DateReturnedWH IS NOT NULL THEN 1 ELSE 0 END) AS recomputed_from_carrier_scan,
    SUM(CASE WHEN DateReturnedWH - DateReturnRequested <= 10
              AND DateReturnedWH IS NOT NULL THEN 1 ELSE 0 END) AS recomputed_from_request,
    SUM(Parcels_for_SLA_measure)    AS flag_sla_population,
    SUM(CASE WHEN Start_Carrier_Journey <= DATE - 10 THEN 1 ELSE 0 END) AS recomputed_population
FROM warehousedb.MB_ZZ_parcels;


/* ---------- Q5 · SoS RECONSTRUCTION: stored SoS vs date arithmetic ---------- */
SEL SUM(CASE WHEN RequestToCarrierSOS <> (Start_Carrier_Journey - DateReturnRequested) THEN 1 ELSE 0 END) AS leg1_mismatch,
    SUM(CASE WHEN CARRIER_SOS         <> (End_Carrier_Journey - Start_Carrier_Journey) THEN 1 ELSE 0 END) AS leg2_mismatch,
    SUM(CASE WHEN WH_SOS              <> (DateReturnedWH - End_Carrier_Journey)        THEN 1 ELSE 0 END) AS leg3_mismatch,
    SUM(CASE WHEN EndToEndSOS         <> (DateReturnedWH - DateReturnRequested)        THEN 1 ELSE 0 END) AS endtoend_mismatch,
    COUNT(*) AS completed_returns
FROM warehousedb.MB_ZZ_parcels
WHERE DateReturnedWH IS NOT NULL;


/* ---------- Q6 · TRACKING JOINABILITY: orphan rates both directions ---------- */
SEL (SEL COUNT(DISTINCT t.RETURNID)
     FROM PRODVM.ZZ_RETURN_IN_TRANSIT t
     LEFT JOIN warehousedb.MB_ZZ_parcels p ON t.RETURNID = p.RETURNID
     WHERE p.RETURNID IS NULL
       AND t.DATETIMEINTRANSIT (DATE) GE DATE - 150)  AS zz_events_orphaned,
    (SEL COUNT(DISTINCT h.hermes_barcode)
     FROM PRODVM.HERMES_RETURN_TRACKING_DETAIL h
     LEFT JOIN warehousedb.MB_ZZ_parcels p ON h.hermes_barcode = p.TRACKINGID
     WHERE p.TRACKINGID IS NULL
       AND h.date_and_time_of_event (DATE) GE DATE - 150) AS evri_events_orphaned;


/* ---------- Q7 · REASON TAXONOMY: distinct reasons + volume (150d) ---------- */
SEL ReturnReason, COUNT(*) AS requests
FROM PRODVM.ZZ_RETURN_REQUESTED
WHERE datetimerequested GE DATE - 150
GROUP BY 1
ORDER BY 2 DESC;


/* ---------- Q8 · CHANNEL SIGNAL: columns of the request source ---------- */
HELP TABLE PRODVM.ZZ_RETURN_REQUESTED;


/* ---------- Q9 · HISTORY DEPTH per source ---------- */
SEL 'MB_ZZ_parcels' AS src, MIN(DateReturnRequested) AS earliest,
       MAX(DateReturnRequested) AS latest, COUNT(*) AS rows_
FROM warehousedb.MB_ZZ_parcels
UNION ALL
SEL 'ZZ_RETURN_REQUESTED', MIN(CAST(datetimerequested AS DATE)),
       MAX(CAST(datetimerequested AS DATE)), COUNT(*)
FROM PRODVM.ZZ_RETURN_REQUESTED
UNION ALL
SEL 'ZZ_RETURN_IN_TRANSIT', MIN(CAST(DATETIMEINTRANSIT AS DATE)),
       MAX(CAST(DATETIMEINTRANSIT AS DATE)), COUNT(*)
FROM PRODVM.ZZ_RETURN_IN_TRANSIT
UNION ALL
SEL 'HERMES_TRACKING', MIN(CAST(date_and_time_of_event AS DATE)),
       MAX(CAST(date_and_time_of_event AS DATE)), COUNT(*)
FROM PRODVM.HERMES_RETURN_TRACKING_DETAIL;


/* ---------- Q10 · FRESHNESS: latest event per source ---------- */
SEL MAX(datetimerequested)      AS latest_request   FROM PRODVM.ZZ_RETURN_REQUESTED;
SEL MAX(DATETIMEINTRANSIT)      AS latest_zz_scan   FROM PRODVM.ZZ_RETURN_IN_TRANSIT;
SEL MAX(date_and_time_of_event) AS latest_evri_scan FROM PRODVM.HERMES_RETURN_TRACKING_DETAIL;


/* ---------- Q11 · REFUND/PAYMENT SOURCE DISCOVERY ---------- */
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


/* ---------- Q12 · NRT FEASIBILITY: PRODVM vs PRODVMUPD freshness ---------- */
SEL 'PRODVM'    AS layer, MAX(datetimerequested) AS latest_request
FROM PRODVM.ZZ_RETURN_REQUESTED
UNION ALL
SEL 'PRODVMUPD', MAX(datetimerequested)
FROM PRODVMUPD.ZZ_RETURN_REQUESTED;

SEL 'PRODVM'    AS layer, MAX(DATETIMEINTRANSIT) AS latest_scan
FROM PRODVM.ZZ_RETURN_IN_TRANSIT
UNION ALL
SEL 'PRODVMUPD', MAX(DATETIMEINTRANSIT)
FROM PRODVMUPD.ZZ_RETURN_IN_TRANSIT;


/* ---------- Q13 · MART LAG: raw request stream vs mart, last 5 days ---------- */
SEL CAST(datetimerequested AS DATE) AS d, COUNT(*) AS raw_requests
FROM PRODVMUPD.ZZ_RETURN_REQUESTED
WHERE datetimerequested GE DATE - 5
GROUP BY 1 ORDER BY 1;

SEL DateReturnRequested AS d, SUM(ReturnsRequested) AS mart_requests
FROM warehousedb.MB_ZZ_parcels
WHERE DateReturnRequested GE DATE - 5
GROUP BY 1 ORDER BY 1;


/* ---------- Q14 · PAYMENT-METHOD SIGNAL in the orderline source ---------- */
HELP TABLE PRODUCTION_ORDERLINE.orderline_current;

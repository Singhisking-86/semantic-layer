/* ============================================================
   ANSWERED · CAT-SWEEP-01 (legacy Q25–Q29) — produced data/catalog dump.
   See ../REGISTER.md and ../../docs/02_source_catalog.md.
   CATALOG-WIDE DISCOVERY — beyond the PBIX object list
   Q25–CAT-SWEEP-01 (legacy Q29) · scans DBC for ALL returns-process-relevant objects.
   Exclusions per earlier decision: DEVT*, UK1_*, sampledb, suppdb.
   Export each result to CSV and upload.
   ============================================================ */

/* ---------- CAT-SWEEP-01 (legacy Q25) · TABLE-NAME SWEEP: every object touching the
   returns/refund/parcel/carrier/warehouse domain ---------- */
SEL DatabaseName, TableName, TableKind, CreateTimeStamp, LastAlterTimeStamp
FROM DBC.TablesV
WHERE TableKind IN ('T','V','O')
  AND (   LOWER(TableName) LIKE '%return%'
       OR LOWER(TableName) LIKE '%refund%'
       OR LOWER(TableName) LIKE '%parcel%'
       OR LOWER(TableName) LIKE '%tracking%'
       OR LOWER(TableName) LIKE '%carrier%'
       OR LOWER(TableName) LIKE '%despatch%'
       OR LOWER(TableName) LIKE '%warehouse%'
       OR LOWER(TableName) LIKE '%exchange%'
       OR LOWER(TableName) LIKE '%zigzag%'
       OR LOWER(TableName) LIKE '%zz_%'
       OR LOWER(TableName) LIKE '%hermes%'
       OR LOWER(TableName) LIKE '%evri%')
  AND LOWER(DatabaseName) NOT LIKE 'devt%'
  AND LOWER(DatabaseName) NOT LIKE 'uk1_%'
  AND LOWER(DatabaseName) NOT IN ('sampledb','suppdb')
ORDER BY DatabaseName, TableName;


/* ---------- CAT-SWEEP-01 (legacy Q26) · COLUMN-NAME SWEEP: find tables by the KEYS they
   carry, regardless of what the table is called. This is the real
   "don't trust the PBIX list" scan — any object with a ReturnID,
   tracking barcode, refund or payment column surfaces here. ---------- */
SEL c.DatabaseName, c.TableName, c.ColumnName, t.TableKind
FROM DBC.ColumnsV c
JOIN DBC.TablesV t
  ON c.DatabaseName = t.DatabaseName AND c.TableName = t.TableName
WHERE t.TableKind IN ('T','V','O')
  AND (   LOWER(c.ColumnName) LIKE '%returnid%'
       OR LOWER(c.ColumnName) LIKE '%return_id%'
       OR LOWER(c.ColumnName) LIKE '%return_number%'
       OR LOWER(c.ColumnName) LIKE '%trackingid%'
       OR LOWER(c.ColumnName) LIKE '%tracking_number%'
       OR LOWER(c.ColumnName) LIKE '%barcode%'
       OR LOWER(c.ColumnName) LIKE '%refund%'
       OR LOWER(c.ColumnName) LIKE '%payment_method%'
       OR LOWER(c.ColumnName) LIKE '%return_reason%')
  AND LOWER(c.DatabaseName) NOT LIKE 'devt%'
  AND LOWER(c.DatabaseName) NOT LIKE 'uk1_%'
  AND LOWER(c.DatabaseName) NOT IN ('sampledb','suppdb')
ORDER BY c.DatabaseName, c.TableName, c.ColumnName;


/* ---------- CAT-SWEEP-01 (legacy Q27) · COMMENT SWEEP: objects documented as returns/refund
   related even when names don't match the patterns ---------- */
SEL DatabaseName, TableName, TableKind, CommentString
FROM DBC.TablesV
WHERE CommentString IS NOT NULL
  AND (   LOWER(CommentString) LIKE '%return%'
       OR LOWER(CommentString) LIKE '%refund%'
       OR LOWER(CommentString) LIKE '%parcel%')
  AND LOWER(DatabaseName) NOT LIKE 'devt%'
  AND LOWER(DatabaseName) NOT LIKE 'uk1_%'
  AND LOWER(DatabaseName) NOT IN ('sampledb','suppdb')
ORDER BY DatabaseName, TableName;


/* ---------- CAT-SWEEP-01 (legacy Q28) · FULL COLUMN DUMP of the two core raw tables —
   the actual schema, not the PBIX's column selection. Replaces the
   guessed OrderNumber/OrderItemNumber names in Q20/Q21/Q24. ---------- */
SEL c.DatabaseName, c.TableName, c.ColumnId, c.ColumnName, c.ColumnType,
    c.ColumnLength, c.Nullable
FROM DBC.ColumnsV c
WHERE (c.DatabaseName = 'PRODVM' AND c.TableName = 'ZZ_RETURN_REQUESTED')
   OR (c.DatabaseName = 'PRODVM' AND c.TableName = 'ZZ_RETURN_IN_TRANSIT')
   OR (c.DatabaseName = 'Production' AND c.TableName = 'ZZ_RETURN_REQUESTED')
   OR (c.DatabaseName = 'Production' AND c.TableName = 'ZZ_RETURN_IN_TRANSIT')
ORDER BY c.DatabaseName, c.TableName, c.ColumnId;
/* If PRODVM rows show NULL ColumnType (view limitation), the
   Production base-table rows in the same output give the types. */


/* ---------- CAT-SWEEP-01 (legacy Q29) · DATABASE INVENTORY: what else lives in the
   databases we already know are in-domain? Catches sibling tables
   (e.g. a refund or WH-scan table sitting next to MB_ZZ_parcels). ---------- */
SEL DatabaseName, TableName, TableKind, LastAlterTimeStamp
FROM DBC.TablesV
WHERE TableKind IN ('T','V','O')
  AND DatabaseName IN ('PRODVM','PRODVMUPD','Production',
                       'Production_Daily_Updated_01','PRODUCTION_DAILY_UPDATED_02',
                       'WAREHOUSEDB','PRODUCTION_ORDERLINE','PRODUCTION_REFRESH',
                       'Production_Reference','zendor_daily_updated_02')
ORDER BY DatabaseName, TableName;
/* WAREHOUSEDB included deliberately: DBC.TablesV lists objects even
   where you can't SELECT from them — the inventory itself is useful. */

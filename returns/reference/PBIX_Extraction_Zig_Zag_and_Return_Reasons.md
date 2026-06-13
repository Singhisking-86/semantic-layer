# PBIX Reverse-Engineering: Zig Zag Returns & Return Reasons

Both reports connect to the same Teradata server: **`teradata2690`** (native query mode, `Teradata.Database` connector, `HierarchicalNavigation=true`).

---

# PART 1 — ZIG ZAG RETURNS

## 1.1 Model overview

| Table (Power BI) | Source Teradata object | Load filter |
|---|---|---|
| `Returns` (fact) | `warehousedb.MB_ZZ_parcels` | none (full table) |
| `ZZ Tracking` | `zz_return_in_transit` | last 90 days (`datetimeintransit`) |
| `EVRI Tracking` | `HERMES_RETURN_TRACKING_DETAIL` joined to `despatch_event_code` | last 90 days (`date_and_time_of_event`) |
| `CALENDAR` / `CALENDAR 2` / `CALENDAR 3` / `CALENDAR 4` | `prodvm.calendar_mart` | `calendar_date <= today` and `>= '2025-11-10'` |

Four identical calendar copies exist because the fact table has four different date roles (a role-playing dimension pattern).

### Relationships

| From (many) | To (one) | Active |
|---|---|---|
| `Returns[DateReturnRequested]` | `CALENDAR[CALENDAR_DATE]` | Yes |
| `Returns[DateReturnedWH]` | `CALENDAR 2[CALENDAR_DATE]` | Yes |
| `Returns[Start_Carrier_Journey]` | `CALENDAR 3[CALENDAR_DATE]` | Yes |
| `Returns[End_Carrier_Journey]` | `CALENDAR 4[CALENDAR_DATE]` | Yes |
| `ZZ Tracking[RETURNID]` | `Returns[RETURNID]` | Yes |
| `EVRI Tracking[HERMES_BARCODE]` | `Returns[TRACKINGID]` | Yes |

All M:1, single-direction cross-filter.

## 1.2 Source SQL (Teradata)

### Returns (fact)

```sql
SEL * FROM warehousedb.MB_ZZ_parcels;
```

Columns in the model (36): trading_code, account_number, order_number, RETURNID, CARRIERSERVICE, DateReturnRequested, EndToEndSOS, ParcelsProcessedByWH, Unreturned/Unprocessed, ReturnsRequested, IdleReturnRequests, ParcelsInTransit, ParcelStatus, Carrier/WH SOS, RequestToCarrierSOS, customer_number, CARRIER, TRACKINGID, Start_Carrier_Journey, End_Carrier_Journey, CARRIER_SOS, Last_Tracking_Event, ZZ_Tracking_Event_count, Matched_item, Matched_product, Matched_order, DateReturnedWH, WH_SOS, Parcels at WH - WIP, ExcludedParcels_NoWHDeliveryScan, Returned_in_10_SLA, Returned_outside_10_SLA, Not_returned_SLA, Parcels_for_SLA_measure, SLA_Status, Target 95%.

### ZZ Tracking

```sql
SEL *
FROM zz_return_in_transit
WHERE datetimeintransit (DATE) GE DATE - 90;
```

Columns: RETURNID, DATETIMEINTRANSIT, TRACKINGID, LASTTRACKINGSTATUS.

### EVRI Tracking

```sql
SEL hermes_barcode,
    jdw_event_code,
    despatch_event_desc,
    date_and_time_of_event
FROM HERMES_RETURN_TRACKING_DETAIL t1
LEFT JOIN despatch_event_code t2
  ON t1.jdw_event_code = t2.despatch_event_code
WHERE date_and_time_of_event (DATE) GE DATE - 90;
```

### CALENDAR (and copies 2/3/4 — identical SQL)

```sql
SEL calendar_date,
    CAST(calendar_date AS DATE FORMAT 'e4') (CHAR(3)) AS Weekday,
    traddly_rel_day_to_now            AS Day_Relevance_to_now,
    finwkly_date_of_week_end          AS date_of_week_end,
    finwkly_rel_week_to_now           AS Fin_Week_Relevance_to_now,
    finwkly_rel_of_period_in_year     AS Fin_Period_Relevance_in_Year, -- resets each year
    finwkly_rel_half_to_now           AS Fin_Half_Relevance_to_now,
    finwkly_rel_year_to_now           AS Fin_Year_Relevance_to_now,
    finwkly_name_of_year              AS FIN_YEAR,
    finwkly_date_of_year_start        AS Start_of_Fin_year,
    finwkly_date_of_year_end          AS End_of_Fin_year,
    finwkly_name_of_half_in_year      AS Season,
    finwkly_no_of_period_in_year      AS Fin_Period,
    CASE WHEN Fin_Period = 1  THEN 'MAR'
         WHEN Fin_Period = 2  THEN 'APR'
         WHEN Fin_Period = 3  THEN 'MAY'
         WHEN Fin_Period = 4  THEN 'JUN'
         WHEN Fin_Period = 5  THEN 'JUL'
         WHEN Fin_Period = 6  THEN 'AUG'
         WHEN Fin_Period = 7  THEN 'SEP'
         WHEN Fin_Period = 8  THEN 'OCT'
         WHEN Fin_Period = 9  THEN 'NOV'
         WHEN Fin_Period = 10 THEN 'DEC'
         WHEN Fin_Period = 11 THEN 'JAN'
         WHEN Fin_Period = 12 THEN 'FEB'
         ELSE NULL END AS Fin_Month_Name,
    CASE WHEN Fin_Period IN (1,2,3)    THEN 'Q1'
         WHEN Fin_Period IN (4,5,6)    THEN 'Q2'
         WHEN Fin_Period IN (7,8,9,10) THEN 'Q3'
         WHEN Fin_Period IN (11,12)    THEN 'Q4'
    END AS Fin_Quarter,
    CASE WHEN Fin_Quarter IN ('Q1','Q2') THEN 'H1'
         WHEN Fin_Quarter IN ('Q3','Q4') THEN 'H2'
    END AS Fin_Half,
    finwkly_no_of_week_in_year AS Fin_Week,
    TRIM(finwkly_name_of_year)||'-'||TRIM(TO_CHAR(finwkly_no_of_week_in_year,'00')) AS Fin_Year_Week
FROM prodvm.calendar_mart
WHERE calendar_date LE DATE
  AND calendar_date (DATE) GE '2025-11-10';
```

## 1.3 Power Query (M) transformations

**Returns:** type-cast `order_number` → text; cast all dates (`DateReturnRequested`, `Start_Carrier_Journey`, `End_Carrier_Journey`, `Last_Tracking_Event`, `Matched_item`, `Matched_product`, `Matched_order`, `DateReturnedWH`); rename `Parcels_at_WH_WIP` → `Parcels at WH - WIP`, `CARIER_SOS` → `CARRIER_SOS`.

**ZZ Tracking / EVRI Tracking:** no transformations — raw query load.

**CALENDAR (all 4 copies):** after type-casting dates, M adds:
- `Day of week SORT` = `Date.DayOfWeek([CALENDAR_DATE], 0)`  (Sunday = 0)
- `FY HALF` = `FIN_YEAR & "-" & Fin_Half`
- `FY QUARTER` = `FIN_YEAR & "-" & Fin_Quarter`
- `FY PERIOD` = `FIN_YEAR & "-" & Fin_Period`
- `FY PERIOD (sort)` = `FIN_YEAR * 100 + Fin_Period` (Int64)

## 1.4 DAX

### Measures (all on `Returns`)

```dax
% Parcels ProcessedBy WH =
DIVIDE ( SUM ( 'Returns'[ParcelsProcessedByWH] ), SUM ( 'Returns'[ReturnsRequested] ) )

% Idle Return Requests =
DIVIDE ( SUM ( 'Returns'[IdleReturnRequests] ), SUM ( 'Returns'[ReturnsRequested] ) )

% Parcels in Transit =
DIVIDE ( SUM ( 'Returns'[ParcelsInTransit] ), SUM ( 'Returns'[ReturnsRequested] ) )

% Parcels at WH - WIP =
DIVIDE ( SUM ( 'Returns'[Parcels at WH - WIP] ), SUM ( 'Returns'[ReturnsRequested] ) )

% Parcels Returned in 10 Day SLA =
DIVIDE ( SUM ( Returns[Returned_in_10_SLA] ), SUM ( Returns[Parcels_for_SLA_measure] ) )

% Parcels Returned outside 10 Day SLA =
DIVIDE ( SUM ( Returns[Returned_outside_10_SLA] ), SUM ( Returns[Parcels_for_SLA_measure] ) )

% Parcels Not Returned (SLA) =
DIVIDE ( SUM ( Returns[Not_returned_SLA] ), SUM ( Returns[Parcels_for_SLA_measure] ) )
```

### Calculated columns

```dax
-- CALENDAR
Date LY        = DATEADD ( 'CALENDAR'[CALENDAR_DATE], -364, DAY )
TodayMinus14   = TODAY() - 15        -- note: actually minus 15 on CALENDAR
TodayMinus10   = TODAY() - 11

-- CALENDAR 2
TodayMinus14   = TODAY() - 14

-- CALENDAR 3
TodayMinus10            = TODAY() - 11
Cal. Month              = FORMAT ( 'CALENDAR 3'[calendar_date], "MMMM" )
Cal. Year               = YEAR ( 'CALENDAR 3'[calendar_date] )
Calendar Month Number   = MONTH ( 'CALENDAR 3'[calendar_date] )

-- Returns
Target 95% = 0.95
```

---

# PART 2 — RETURN REASONS

## 2.1 Model overview

| Table (Power BI) | Source Teradata objects | Load filter |
|---|---|---|
| `Returns Data` (fact, grain = return request line) | `zz_return_requested` + `product_summary` + `product_Status_code` + `product_option` + `supplier_new` | last 90 days (`datetimerequested`) |
| `Returns Rate data` (product-level aggregate) | `orderline_current` + `warehousedb.zz_return_requested_clean` + `product_summary` + `product_option` + `supplier_new` | last 90 days (`date_of_original_order`), `orderline_status_code = '0'` |
| `CALENDAR` | `prodvm.calendar_mart` | up to yesterday, current + prior fin year |

### Relationship

| From (many) | To (one) |
|---|---|
| `Returns Data[Product_Number]` | `Returns Rate data[PRODUCT_NUMBER]` (M:1, single) |

## 2.2 Source SQL (Teradata)

### Returns Data

```sql
SELECT
    CustomerID AS Customer_ID,
    CASE
        WHEN REGEXP_SIMILAR(SUBSTRING(CustomerID FROM 2), '^[0-9]+$') = 1
        THEN CAST(SUBSTRING(CustomerID FROM 2) AS INTEGER) * 10
        ELSE NULL
    END AS Account_number,
    SUBSTRING(CustomerID,1,1)                          AS Trading_Code,
    ReturnID                                           AS Return_ID,
    COALESCE(SUBSTRING(Carrier,1,LENGTH(carrier)-5),0) AS Carrier,
    CarrierService                                     AS Carrier_Service,
    SKU                                                AS SKU_Full,
    SUBSTRING(SKU,1,5)||SUBSTRING(SKU,LENGTH(sku)-1,LENGTH(sku)) AS SKU_PN_ON,
    SUBSTRING(SKU,1,5)                                 AS Product_Number,
    CAST(SUBSTRING(SKU,LENGTH(sku)-1,LENGTH(sku)) AS VARCHAR(8)) AS Product_Option_number,
    datetimerequested                                  AS Date_Time_Requested,
    CAST(datetimerequested AS DATE)                    AS Date_Requested,
    EXTRACT(YEAR  FROM datetimerequested)              AS Year_Requested,
    EXTRACT(MONTH FROM datetimerequested)              AS Month_Requested,
    ReturnReason                                       AS Return_Reason_Desc,
    TrackingID                                         AS Tracking_ID,
    t2.product_brand_desc,
    t2.Product_Line_Desc,
    t2.product_desc,
    t2.Merchandise_Department_Desc,
    t2.Merchandise_Group_Desc,
    t2.Merchandise_Range_Desc,
    t2.Department_Desc,
    t2.Merch_FMB_Desc,
    t2.product_line_code,
    t2.Department_Group_Desc,
    t3.Product_Status_Desc,
    t2.Buyer_ID,
    t2.Range_Group_Desc,
    Merchandise_Season_Code,
    Colour_Desc,
    Size_Desc,
    t4.Product_Status_Desc,
    t4.supplier_number,
    t5.supplier_name,
    1 AS returns_requests
FROM zz_return_requested t1
LEFT JOIN product_summary t2
       ON SUBSTRING(t1.SKU,1,5) = t2.product_number
LEFT JOIN product_Status_code t3
       ON t2.product_status_code = t3.product_status_code
LEFT JOIN product_option t4
       ON SUBSTRING(t1.SKU,1,5) = t4.product_number
      AND CAST(SUBSTRING(SKU,LENGTH(sku)-1,LENGTH(sku)) AS VARCHAR(8)) = t4.product_option_number
LEFT JOIN supplier_new t5
       ON t4.supplier_number = t5.supplier_number
WHERE datetimerequested GE DATE - 90;
```

### Returns Rate data

```sql
SEL
    t1.product_number,
    t3.product_desc,
    t3.product_image_URL,
    t3.product_brand_desc,
    t3.Product_Line_Desc,
    t3.Merchandise_Department_Desc,
    t3.Merchandise_Group_Desc,
    t3.Merchandise_Range_Desc,
    t3.Department_Desc,
    t3.Merch_FMB_Desc,
    t3.product_line_code,
    t3.Department_Group_Desc,
    t3.Buyer_ID,
    t3.Range_Group_Desc,
    t4.supplier_number,
    t5.supplier_name,
    CAST(t4.supplier_number AS INTEGER)||'_'||TRIM(t5.supplier_name) AS Supplier,
    SUM(t1.orderline_quantity) AS items_ordered,
    SUM(CASE WHEN t2.ReturnID IS NOT NULL THEN 1 ELSE 0 END) AS items_returned
FROM orderline_current t1
LEFT JOIN warehousedb.zz_return_requested_clean t2
       ON t1.account_number      = t2.account_number
      AND t1.trading_code        = t2.trading_code
      AND t1.order_serial_number = t2.order_number
      AND t1.orderline_number    = t2.order_item_number
LEFT JOIN product_summary t3
       ON t1.product_number = t3.product_number
LEFT JOIN product_option t4
       ON t1.product_number        = t4.product_number
      AND t1.product_option_number = t4.product_option_number
LEFT JOIN supplier_new t5
       ON t4.supplier_number = t5.supplier_number
WHERE t1.orderline_status_code = '0'
  AND date_of_original_order GE DATE - 90
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17;
```

M post-step: `Table.Distinct(Source, {"PRODUCT_NUMBER"})` — dedupes to one row per product (note: this keeps an arbitrary first row when a product spans multiple supplier options).

### CALENDAR

Same `prodvm.calendar_mart` query as Zig Zag but with these differences:
- Month names wrapped in parentheses: `'(MAR)'`, `'(APR)'`, …
- Extra column: `F_Month = TRIM(FIN_YEAR)||' '||CAST(CAST(Fin_Period AS FORMAT '9(2)') AS CHAR(2))||' '||Financial_M`
- No `Fin_Week` / `Fin_Year_Week` / year start-end dates
- Filter: `WHERE calendar_date LE DATE - 1 AND Fin_Year_Relevance_to_now GE -1` (yesterday back, current + previous financial year)

## 2.3 DAX

### Measures

```dax
-- Returns Rate data
Return Rate =
DIVIDE ( SUM ( 'Returns Rate data'[items_returned] ), SUM ( 'Returns Rate data'[items_ordered] ) )

-- Returns Data
Returns Requests Measure = SUM ( 'Returns Data'[returns_requests] )

#1 Return Reason (Measure) per product =
CALCULATE (
    SELECTEDVALUE ( 'Returns Data'[Return_Reason_Desc] ),
    'Returns Data'[Reason Rank within Product] = 1
)
-- #2 and #3 identical with rank = 2 / 3

Return Reason % Split =
DIVIDE (
    COUNT ( 'Returns Data'[returns_requests] ),
    CALCULATE (
        COUNT ( 'Returns Data'[returns_requests] ),
        ALLEXCEPT ( 'Returns Data', 'Returns Data'[product_number] )
    )
)

-- Returns Rate data: "#1 Return Reason with %" (and #2, #3 with rank 2/3)
#1 Return Reason with % =
VAR CurrentProduct = SELECTEDVALUE ( 'Returns Data'[product_number] )
VAR TopReason =
    CALCULATE (
        FIRSTNONBLANK ( 'Returns Data'[Return_Reason_Desc], 1 ),
        FILTER (
            'Returns Data',
            'Returns Data'[product_number] = CurrentProduct
                && 'Returns Data'[Reason Rank within Product] = 1
        )
    )
VAR TopCounts =
    CALCULATE (
        COUNT ( 'Returns Data'[returns_requests] ),
        FILTER (
            'Returns Data',
            'Returns Data'[product_number] = CurrentProduct
                && 'Returns Data'[Return_Reason_Desc] = TopReason
        )
    )
VAR TotalProduct =
    CALCULATE (
        COUNT ( 'Returns Data'[returns_requests] ),
        'Returns Data'[product_number] = CurrentProduct
    )
VAR TopPercents = DIVIDE ( TopCounts, TotalProduct, 0 )
RETURN
IF (
    NOT ISBLANK ( TopReason ),
    TopReason & " (" & FORMAT ( TopCounts, "#,0" ) & ") — " & FORMAT ( TopPercents, "0.0%" )
)
```

### Calculated columns

```dax
-- CALENDAR
Date LY = DATEADD ( 'CALENDAR'[CALENDAR_DATE], -364, DAY )

-- Returns Data: reason grouping
Return_Reason_Desc (groups) =
SWITCH (
    TRUE,
    ISBLANK ( 'Returns Data'[Return_Reason_Desc] ), "(Blank)",
    'Returns Data'[Return_Reason_Desc] IN { "Looks different to image on site" }, "Buying",
    'Returns Data'[Return_Reason_Desc] IN {
        "Better Price Found Elsewhere", "Changed my mind", "Doesn't suit me",
        "No longer needed/wanted", "Ordered multiple outfit options",
        "Ordered wrong style/size/colour" }, "Customer Choice",
    'Returns Data'[Return_Reason_Desc] IN {
        "Arrived too late", "Arrived Worn", "Incorrect item received",
        "Missing Parts or Accessories", "Received Item I didn't buy (no refund issued)",
        "Wrong quantity delivered" }, "Delivery/Warehouse",
    'Returns Data'[Return_Reason_Desc] IN {
        "Boot Length Too Short", "Boot Length Too Tall", "Calf Too Narrow", "Calf Too Wide",
        "Doesnt fit me  too big", "Doesnt fit me  too small", "Doesn't fit properly",
        "Foot Too Long", "Foot Too Narrow", "Foot Too Short", "Foot Too Wide",
        "FOOTWEAR - Item does not fit properly", "Ordered more than one size",
        "Product Uncomfortable", "Too long", "Too short" }, "Fit",
    'Returns Data'[Return_Reason_Desc] IN {
        "Damaged or Defective", "Faulty assembly problem",
        "Quality not as expected", "Seal Broken" }, "Quality",
    'Returns Data'[Return_Reason_Desc]
)

-- Returns Data: count of returns per (product, reason) repeated on every row
Returns per Product & Reason =
CALCULATE (
    COUNT ( 'Returns Data'[returns_requests] ),
    ALLEXCEPT ( 'Returns Data', 'Returns Data'[product_number], 'Returns Data'[Return_Reason_Desc] )
)

-- Returns Data: rank of each reason within its product (ties broken alphabetically)
Reason Rank within Product =
RANKX (
    FILTER ( ALL ( 'Returns Data' ),
        'Returns Data'[product_number] = EARLIER ( 'Returns Data'[product_number] ) ),
    VAR ReasonCount =
        CALCULATE (
            COUNT ( 'Returns Data'[returns_requests] ),
            ALLEXCEPT ( 'Returns Data',
                'Returns Data'[product_number], 'Returns Data'[Return_Reason_Desc] )
        )
    RETURN
        ReasonCount * 1000000
            + RANKX ( ALL ( 'Returns Data'[Return_Reason_Desc] ),
                      'Returns Data'[Return_Reason_Desc], , ASC, DENSE ),
    , DESC, DENSE
)

-- Returns Rate data: product rank by items returned (ties broken by product number)
Product Rank =
RANKX (
    ALL ( 'Returns Rate data' ),
    'Returns Rate data'[items_returned] * 1000000
        + RANKX ( ALL ( 'Returns Rate data'[product_number] ),
                  'Returns Rate data'[product_number], , ASC, DENSE ),
    , DESC, DENSE
)
```

---

# Summary of all Teradata source objects

| Object | Used by |
|---|---|
| `warehousedb.MB_ZZ_parcels` | Zig Zag — Returns fact |
| `zz_return_in_transit` | Zig Zag — ZZ Tracking |
| `HERMES_RETURN_TRACKING_DETAIL` | Zig Zag — EVRI Tracking |
| `despatch_event_code` | Zig Zag — EVRI Tracking (event descriptions) |
| `prodvm.calendar_mart` | Both — calendar dimension(s) |
| `zz_return_requested` | Return Reasons — Returns Data fact |
| `warehousedb.zz_return_requested_clean` | Return Reasons — Returns Rate data (return matching) |
| `orderline_current` | Return Reasons — Returns Rate data (demand base) |
| `product_summary` | Return Reasons — product attributes |
| `product_Status_code` | Return Reasons — status descriptions |
| `product_option` | Return Reasons — option/supplier link |
| `supplier_new` | Return Reasons — supplier names |

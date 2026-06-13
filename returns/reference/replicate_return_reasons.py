"""
Replication of the 'Return Reasons' Power BI report in Python.

Pulls the same Teradata sources and rebuilds the DAX logic
(reason grouping, reason ranking within product, return rate, top-3 reasons)
in pandas.

Requirements:
    pip install teradatasql pandas
"""

import pandas as pd
import teradatasql

CONN = dict(host="teradata2690", user="YOUR_USER", password="YOUR_PASSWORD")

# ---------------------------------------------------------------------------
# 0. Source SQL — exactly as embedded in the PBIX
# ---------------------------------------------------------------------------
RETURNS_DATA_SQL = """
SELECT
    CustomerID AS Customer_ID,
    CASE WHEN REGEXP_SIMILAR(SUBSTRING(CustomerID FROM 2), '^[0-9]+$') = 1
         THEN CAST(SUBSTRING(CustomerID FROM 2) AS INTEGER) * 10
         ELSE NULL END AS Account_number,
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
    t2.product_brand_desc, t2.Product_Line_Desc, t2.product_desc,
    t2.Merchandise_Department_Desc, t2.Merchandise_Group_Desc,
    t2.Merchandise_Range_Desc, t2.Department_Desc, t2.Merch_FMB_Desc,
    t2.product_line_code, t2.Department_Group_Desc,
    t3.Product_Status_Desc,
    t2.Buyer_ID, t2.Range_Group_Desc,
    Merchandise_Season_Code, Colour_Desc, Size_Desc,
    t4.Product_Status_Desc AS Option_Status_Desc,
    t4.supplier_number, t5.supplier_name,
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
WHERE datetimerequested GE DATE - 90
"""

RETURNS_RATE_SQL = """
SEL
    t1.product_number, t3.product_desc, t3.product_image_URL,
    t3.product_brand_desc, t3.Product_Line_Desc,
    t3.Merchandise_Department_Desc, t3.Merchandise_Group_Desc,
    t3.Merchandise_Range_Desc, t3.Department_Desc, t3.Merch_FMB_Desc,
    t3.product_line_code, t3.Department_Group_Desc, t3.Buyer_ID,
    t3.Range_Group_Desc, t4.supplier_number, t5.supplier_name,
    CAST(t4.supplier_number AS INTEGER)||'_'||TRIM(t5.supplier_name) AS Supplier,
    SUM(t1.orderline_quantity) AS items_ordered,
    SUM(CASE WHEN t2.ReturnID IS NOT NULL THEN 1 ELSE 0 END) AS items_returned
FROM orderline_current t1
LEFT JOIN warehousedb.zz_return_requested_clean t2
       ON t1.account_number      = t2.account_number
      AND t1.trading_code        = t2.trading_code
      AND t1.order_serial_number = t2.order_number
      AND t1.orderline_number    = t2.order_item_number
LEFT JOIN product_summary t3 ON t1.product_number = t3.product_number
LEFT JOIN product_option  t4 ON t1.product_number = t4.product_number
                            AND t1.product_option_number = t4.product_option_number
LEFT JOIN supplier_new    t5 ON t4.supplier_number = t5.supplier_number
WHERE t1.orderline_status_code = '0'
  AND date_of_original_order GE DATE - 90
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17
"""

CALENDAR_SQL = """
SEL calendar_date,
    CAST(calendar_date AS DATE FORMAT 'e4') (CHAR(3)) AS Weekday,
    traddly_rel_day_to_now        AS Day_Relevance_to_now,
    finwkly_date_of_week_end      AS date_of_week_end,
    finwkly_rel_week_to_now       AS Fin_Week_Relevance_to_now,
    finwkly_rel_of_period_in_year AS Fin_Period_Relevance_in_Year,
    finwkly_rel_half_to_now       AS Fin_Half_Relevance_to_now,
    finwkly_rel_year_to_now       AS Fin_Year_Relevance_to_now,
    finwkly_name_of_year          AS FIN_YEAR,
    finwkly_name_of_half_in_year  AS Season,
    finwkly_no_of_period_in_year  AS Fin_Period,
    CASE WHEN Fin_Period = 1  THEN '(MAR)' WHEN Fin_Period = 2  THEN '(APR)'
         WHEN Fin_Period = 3  THEN '(MAY)' WHEN Fin_Period = 4  THEN '(JUN)'
         WHEN Fin_Period = 5  THEN '(JUL)' WHEN Fin_Period = 6  THEN '(AUG)'
         WHEN Fin_Period = 7  THEN '(SEP)' WHEN Fin_Period = 8  THEN '(OCT)'
         WHEN Fin_Period = 9  THEN '(NOV)' WHEN Fin_Period = 10 THEN '(DEC)'
         WHEN Fin_Period = 11 THEN '(JAN)' WHEN Fin_Period = 12 THEN '(FEB)'
         ELSE NULL END AS Financial_M,
    TRIM(FIN_YEAR)||' '||CAST(CAST(Fin_Period AS FORMAT '9(2)') AS CHAR(2))||' '||Financial_M AS F_Month,
    CASE WHEN Fin_Period IN (1,2,3)    THEN 'Q1'
         WHEN Fin_Period IN (4,5,6)    THEN 'Q2'
         WHEN Fin_Period IN (7,8,9,10) THEN 'Q3'
         WHEN Fin_Period IN (11,12)    THEN 'Q4' END AS Fin_Quarter,
    CASE WHEN Fin_Quarter IN ('Q1','Q2') THEN 'H1'
         WHEN Fin_Quarter IN ('Q3','Q4') THEN 'H2' END AS Fin_Half
FROM prodvm.calendar_mart
WHERE calendar_date LE DATE - 1
  AND Fin_Year_Relevance_to_now GE -1
"""


def load(sql: str) -> pd.DataFrame:
    with teradatasql.connect(**CONN) as con:
        return pd.read_sql(sql, con)


# ---------------------------------------------------------------------------
# 1. DAX calculated column: Return_Reason_Desc (groups)
# ---------------------------------------------------------------------------
REASON_GROUPS = {
    "Buying": ["Looks different to image on site"],
    "Customer Choice": [
        "Better Price Found Elsewhere", "Changed my mind", "Doesn't suit me",
        "No longer needed/wanted", "Ordered multiple outfit options",
        "Ordered wrong style/size/colour"],
    "Delivery/Warehouse": [
        "Arrived too late", "Arrived Worn", "Incorrect item received",
        "Missing Parts or Accessories",
        "Received Item I didn't buy (no refund issued)", "Wrong quantity delivered"],
    "Fit": [
        "Boot Length Too Short", "Boot Length Too Tall", "Calf Too Narrow",
        "Calf Too Wide", "Doesnt fit me  too big", "Doesnt fit me  too small",
        "Doesn't fit properly", "Foot Too Long", "Foot Too Narrow",
        "Foot Too Short", "Foot Too Wide",
        "FOOTWEAR - Item does not fit properly", "Ordered more than one size",
        "Product Uncomfortable", "Too long", "Too short"],
    "Quality": [
        "Damaged or Defective", "Faulty assembly problem",
        "Quality not as expected", "Seal Broken"],
}
REASON_TO_GROUP = {r: g for g, rs in REASON_GROUPS.items() for r in rs}


def add_reason_group(df: pd.DataFrame) -> pd.DataFrame:
    df["Return_Reason_Desc (groups)"] = (
        df["Return_Reason_Desc"]
        .map(REASON_TO_GROUP)
        .fillna(df["Return_Reason_Desc"])   # unmapped reasons pass through
        .fillna("(Blank)")                  # nulls -> (Blank)
    )
    return df


# ---------------------------------------------------------------------------
# 2. DAX columns: Returns per Product & Reason  +  Reason Rank within Product
#    (rank by count desc; ties broken alphabetically by reason — replicates
#     the count*1e6 + alpha-rank trick in the DAX)
# ---------------------------------------------------------------------------
def add_reason_rank(df: pd.DataFrame) -> pd.DataFrame:
    counts = (df.groupby(["Product_Number", "Return_Reason_Desc"])["returns_requests"]
                .count().rename("Returns per Product & Reason").reset_index())
    counts = counts.sort_values(
        ["Product_Number", "Returns per Product & Reason", "Return_Reason_Desc"],
        ascending=[True, False, True])
    counts["Reason Rank within Product"] = counts.groupby("Product_Number").cumcount() + 1
    return df.merge(counts, on=["Product_Number", "Return_Reason_Desc"], how="left")


# ---------------------------------------------------------------------------
# 3. DAX measures
# ---------------------------------------------------------------------------
def return_rate(rate_df: pd.DataFrame) -> float:
    """Return Rate = SUM(items_returned) / SUM(items_ordered)."""
    return rate_df["items_returned"].sum() / rate_df["items_ordered"].sum()


def top_reasons_with_pct(returns_df: pd.DataFrame, top_n: int = 3) -> pd.DataFrame:
    """Replicates '#1/#2/#3 Return Reason with %' per product."""
    grp = (returns_df.groupby(["Product_Number", "Return_Reason_Desc"])
           .size().rename("cnt").reset_index())
    grp["total"] = grp.groupby("Product_Number")["cnt"].transform("sum")
    grp["pct"] = grp["cnt"] / grp["total"]
    grp = grp.sort_values(["Product_Number", "cnt", "Return_Reason_Desc"],
                          ascending=[True, False, True])
    grp["rank"] = grp.groupby("Product_Number").cumcount() + 1
    grp = grp[grp["rank"] <= top_n].copy()
    grp["label"] = (grp["Return_Reason_Desc"] + " (" + grp["cnt"].map("{:,}".format)
                    + ") — " + (grp["pct"] * 100).round(1).astype(str) + "%")
    return (grp.pivot(index="Product_Number", columns="rank", values="label")
               .rename(columns={1: "#1 Return Reason with %",
                                2: "#2 Return Reason with %",
                                3: "#3 Return Reason with %"}))


def product_rank(rate_df: pd.DataFrame) -> pd.DataFrame:
    """Replicates 'Product Rank' (items_returned desc, ties by product number asc)."""
    out = rate_df.sort_values(["items_returned", "PRODUCT_NUMBER"],
                              ascending=[False, True]).copy()
    out["Product Rank"] = range(1, len(out) + 1)
    return out


# ---------------------------------------------------------------------------
# 4. Main
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    returns_data = load(RETURNS_DATA_SQL)
    returns_rate = load(RETURNS_RATE_SQL)
    calendar = load(CALENDAR_SQL)

    # M step on Returns Rate data: distinct on PRODUCT_NUMBER
    returns_rate.columns = [c.upper() if c.lower() == "product_number" else c
                            for c in returns_rate.columns]
    returns_rate = returns_rate.drop_duplicates(subset=["PRODUCT_NUMBER"], keep="first")

    # DAX replication
    returns_data = add_reason_group(returns_data)
    returns_data = add_reason_rank(returns_data)
    returns_rate = product_rank(returns_rate)

    print("Overall return rate: {:.2%}".format(return_rate(returns_rate)))
    print(top_reasons_with_pct(returns_data).head(10))

    # Relationship: Returns Data[Product_Number] -> Returns Rate data[PRODUCT_NUMBER]
    model = returns_data.merge(
        returns_rate[["PRODUCT_NUMBER", "items_ordered", "items_returned", "Product Rank"]],
        left_on="Product_Number", right_on="PRODUCT_NUMBER", how="left")

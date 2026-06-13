"""
Replication of the 'Zig Zag Returns' Power BI report in Python.

Pulls the same Teradata sources, rebuilds the Power Query (M) transformations
and the DAX measures/columns in pandas.

Requirements:
    pip install teradatasql pandas
"""

import pandas as pd
import teradatasql

# ---------------------------------------------------------------------------
# 0. Connection — teradata2690 (same server the PBIX uses)
# ---------------------------------------------------------------------------
CONN = dict(host="teradata2690", user="YOUR_USER", password="YOUR_PASSWORD")

CALENDAR_SQL = """
SEL calendar_date,
    CAST(calendar_date AS DATE FORMAT 'e4') (CHAR(3)) AS Weekday,
    traddly_rel_day_to_now            AS Day_Relevance_to_now,
    finwkly_date_of_week_end          AS date_of_week_end,
    finwkly_rel_week_to_now           AS Fin_Week_Relevance_to_now,
    finwkly_rel_of_period_in_year     AS Fin_Period_Relevance_in_Year,
    finwkly_rel_half_to_now           AS Fin_Half_Relevance_to_now,
    finwkly_rel_year_to_now           AS Fin_Year_Relevance_to_now,
    finwkly_name_of_year              AS FIN_YEAR,
    finwkly_date_of_year_start        AS Start_of_Fin_year,
    finwkly_date_of_year_end          AS End_of_Fin_year,
    finwkly_name_of_half_in_year      AS Season,
    finwkly_no_of_period_in_year      AS Fin_Period,
    CASE WHEN Fin_Period = 1  THEN 'MAR' WHEN Fin_Period = 2  THEN 'APR'
         WHEN Fin_Period = 3  THEN 'MAY' WHEN Fin_Period = 4  THEN 'JUN'
         WHEN Fin_Period = 5  THEN 'JUL' WHEN Fin_Period = 6  THEN 'AUG'
         WHEN Fin_Period = 7  THEN 'SEP' WHEN Fin_Period = 8  THEN 'OCT'
         WHEN Fin_Period = 9  THEN 'NOV' WHEN Fin_Period = 10 THEN 'DEC'
         WHEN Fin_Period = 11 THEN 'JAN' WHEN Fin_Period = 12 THEN 'FEB'
         ELSE NULL END AS Fin_Month_Name,
    CASE WHEN Fin_Period IN (1,2,3)    THEN 'Q1'
         WHEN Fin_Period IN (4,5,6)    THEN 'Q2'
         WHEN Fin_Period IN (7,8,9,10) THEN 'Q3'
         WHEN Fin_Period IN (11,12)    THEN 'Q4' END AS Fin_Quarter,
    CASE WHEN Fin_Quarter IN ('Q1','Q2') THEN 'H1'
         WHEN Fin_Quarter IN ('Q3','Q4') THEN 'H2' END AS Fin_Half,
    finwkly_no_of_week_in_year AS Fin_Week,
    TRIM(finwkly_name_of_year)||'-'||TRIM(TO_CHAR(finwkly_no_of_week_in_year,'00')) AS Fin_Year_Week
FROM prodvm.calendar_mart
WHERE calendar_date LE DATE
  AND calendar_date (DATE) GE '2025-11-10'
"""

RETURNS_SQL = "SEL * FROM warehousedb.MB_ZZ_parcels"

ZZ_TRACKING_SQL = """
SEL * FROM zz_return_in_transit
WHERE datetimeintransit (DATE) GE DATE - 90
"""

EVRI_TRACKING_SQL = """
SEL hermes_barcode, jdw_event_code, despatch_event_desc, date_and_time_of_event
FROM HERMES_RETURN_TRACKING_DETAIL t1
LEFT JOIN despatch_event_code t2
  ON t1.jdw_event_code = t2.despatch_event_code
WHERE date_and_time_of_event (DATE) GE DATE - 90
"""


def load(sql: str) -> pd.DataFrame:
    with teradatasql.connect(**CONN) as con:
        return pd.read_sql(sql, con)


# ---------------------------------------------------------------------------
# 1. Power Query (M) transformations replicated
# ---------------------------------------------------------------------------
def transform_calendar(cal: pd.DataFrame) -> pd.DataFrame:
    """Replicates the M steps applied to all four CALENDAR copies."""
    date_cols = ["CALENDAR_DATE", "date_of_week_end", "Start_of_Fin_year", "End_of_Fin_year"]
    cal.columns = [c.upper() if c.lower() == "calendar_date" else c for c in cal.columns]
    for c in date_cols:
        cal[c] = pd.to_datetime(cal[c])

    # Day of week SORT (Sunday=0, matching Date.DayOfWeek([d],0) with Sunday first)
    cal["Day of week SORT"] = (cal["CALENDAR_DATE"].dt.dayofweek + 1) % 7

    cal["FY HALF"]    = cal["FIN_YEAR"].astype(str) + "-" + cal["Fin_Half"]
    cal["FY QUARTER"] = cal["FIN_YEAR"].astype(str) + "-" + cal["Fin_Quarter"]
    cal["FY PERIOD"]  = cal["FIN_YEAR"].astype(str) + "-" + cal["Fin_Period"].astype(str)
    cal["FY PERIOD (sort)"] = cal["FIN_YEAR"].astype(int) * 100 + cal["Fin_Period"].astype(int)
    return cal


def transform_returns(ret: pd.DataFrame) -> pd.DataFrame:
    """Replicates the M steps on the Returns fact."""
    ret["order_number"] = ret["order_number"].astype(str)
    for c in ["DateReturnRequested", "Start_Carrier_Journey", "End_Carrier_Journey",
              "Last_Tracking_Event", "Matched_item", "Matched_product",
              "Matched_order", "DateReturnedWH"]:
        ret[c] = pd.to_datetime(ret[c])
    ret = ret.rename(columns={"Parcels_at_WH_WIP": "Parcels at WH - WIP",
                              "CARIER_SOS": "CARRIER_SOS"})
    return ret


# ---------------------------------------------------------------------------
# 2. DAX calculated columns replicated
# ---------------------------------------------------------------------------
def add_calendar_dax_columns(cal: pd.DataFrame, which: str) -> pd.DataFrame:
    today = pd.Timestamp.today().normalize()
    if which == "CALENDAR":
        cal["Date LY"] = cal["CALENDAR_DATE"] - pd.Timedelta(days=364)
        cal["TodayMinus14"] = today - pd.Timedelta(days=15)   # PBIX really uses -15 here
        cal["TodayMinus10"] = today - pd.Timedelta(days=11)
    elif which == "CALENDAR 2":
        cal["TodayMinus14"] = today - pd.Timedelta(days=14)
    elif which == "CALENDAR 3":
        cal["TodayMinus10"] = today - pd.Timedelta(days=11)
        cal["Cal. Month"] = cal["CALENDAR_DATE"].dt.strftime("%B")
        cal["Cal. Year"] = cal["CALENDAR_DATE"].dt.year
        cal["Calendar Month Number"] = cal["CALENDAR_DATE"].dt.month
    return cal


# ---------------------------------------------------------------------------
# 3. DAX measures replicated (operate on any filtered slice of Returns)
# ---------------------------------------------------------------------------
def measures(returns_slice: pd.DataFrame) -> dict:
    s = returns_slice
    def div(n, d): return n / d if d else None
    return {
        "% Parcels ProcessedBy WH":            div(s["ParcelsProcessedByWH"].sum(), s["ReturnsRequested"].sum()),
        "% Idle Return Requests":              div(s["IdleReturnRequests"].sum(), s["ReturnsRequested"].sum()),
        "% Parcels in Transit":                div(s["ParcelsInTransit"].sum(), s["ReturnsRequested"].sum()),
        "% Parcels at WH - WIP":               div(s["Parcels at WH - WIP"].sum(), s["ReturnsRequested"].sum()),
        "% Parcels Returned in 10 Day SLA":    div(s["Returned_in_10_SLA"].sum(), s["Parcels_for_SLA_measure"].sum()),
        "% Parcels Returned outside 10 Day SLA": div(s["Returned_outside_10_SLA"].sum(), s["Parcels_for_SLA_measure"].sum()),
        "% Parcels Not Returned (SLA)":        div(s["Not_returned_SLA"].sum(), s["Parcels_for_SLA_measure"].sum()),
        "Target 95%":                          0.95,
    }


# ---------------------------------------------------------------------------
# 4. Main
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    cal_raw = transform_calendar(load(CALENDAR_SQL))
    # Four role-playing copies (PBIX duplicates the query; here we just copy)
    calendar_1 = add_calendar_dax_columns(cal_raw.copy(), "CALENDAR")     # DateReturnRequested
    calendar_2 = add_calendar_dax_columns(cal_raw.copy(), "CALENDAR 2")   # DateReturnedWH
    calendar_3 = add_calendar_dax_columns(cal_raw.copy(), "CALENDAR 3")   # Start_Carrier_Journey
    calendar_4 = cal_raw.copy()                                           # End_Carrier_Journey

    returns = transform_returns(load(RETURNS_SQL))
    zz_tracking = load(ZZ_TRACKING_SQL)      # joins to returns on RETURNID
    evri_tracking = load(EVRI_TRACKING_SQL)  # joins to returns on HERMES_BARCODE = TRACKINGID

    # Example: relationships as merges
    returns_enriched = (
        returns
        .merge(calendar_1[["CALENDAR_DATE", "FIN_YEAR", "Fin_Period", "Fin_Year_Week"]],
               left_on="DateReturnRequested", right_on="CALENDAR_DATE", how="left")
    )

    # Example: overall measure values + weekly SLA trend
    print(pd.Series(measures(returns)))
    weekly = (returns_enriched.groupby("Fin_Year_Week")
              .apply(lambda g: pd.Series(measures(g))))
    print(weekly.tail(10))

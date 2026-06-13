# P11 aggregated (computed from P11_cdc_lag_raw.csv, 49,931 rows)
mean 1.75d · median 1.64d · p5 0.84d · p25 0.99d · p75 2.13d · p95 3.60d · p99 3.76d · max 3.80d
Buckets: negative 0.4% · <1d 25.7% · 1-2d 46.4% · 2-3d 17.4% · 3-4d 10.1%
Six fractional-second batch signatures (.920/.260/.930/.660/.370/.280) cover 99.6% of rows -> ~daily bulk loads.
Negative lag: 188 rows (0.38%), worst -24.3 days -> DQ anomaly cohort (rule R7).

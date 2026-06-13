# Archived SQL — superseded, kept for provenance only. Do not run.

| File | Superseded by | Why |
|------|---------------|-----|
| `Phase1_Validation_Q1_Q14.sql` | `../open/Phase1_Validation_Revised_No_Warehousedb.sql` | Original Phase-1 plan. Q6/Q13 referenced `warehousedb` (no SELECT access); the revised file drops those and adds Q15–Q19. Q1–Q5 were run from this design but offline on the mart snapshot. |
| `Grain_Validation_Q20_Q24.sql` | `../answered/Profile_ZZ_Tables_FINAL_P1_P14.sql` | Early grain probes written before real column names were known (assumed `OrderNumber`/`OrderItemNumber`). The same questions were re-run correctly as P1–P9. Mapping: Q20→RET-GRAIN-01, Q21→RET-GRAIN-03, Q22→RET-TRANSIT-02, Q23→RET-TRANSIT-03, Q24→RET-GRAIN-04. |
| `Profile_ZZ_Requested_InTransit_P0_P9.sql` | `../answered/Profile_ZZ_Tables_FINAL_P1_P14.sql` | First profiling draft with `<PLACEHOLDER>` column names (P0 was the schema probe to fill them). The FINAL file is the actual run with real columns. |

See `../REGISTER.md` for the canonical question→status→verdict map.

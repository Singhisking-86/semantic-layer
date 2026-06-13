# Tier 3 · Source Bindings (ACTIVE)

The ONLY tier that knows physical sources exist (Teradata now, Databricks later).
Declarative mappings from tier-2 contracts to actual objects + load rules R1–R7 +
watermarks. A source/engine swap = rewrite these specs, leave tiers 1–2 untouched.

- `bindings_teradata.md` (author now) — each tier-2 entity/state mapped to PRODVM
  objects with the exact rule applied. E.g. state ② := first IN_TRANSIT milestone
  in PRODVM.ZZ_RETURN_IN_TRANSIT (deduped R1), fallback first EVRI scan; ⑤ :=
  event 0097 in RETURN_ITEM_EVENT_HISTORY; watermark on INSERTED_ON +7d (R7).
- `bindings_databricks.md` (later) — same contracts, Databricks objects.
- Pending unblock: P15 bridge repair (ZZ→WMS) before ④/⑤ bindings finalize.

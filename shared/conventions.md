# Cross-Domain Conventions

## SQL question ID scheme

Every investigative SQL question gets a stable, topic-keyed ID. Assigned once,
never renumbered, never reused across domains.

| Prefix | Domain | Example |
|--------|--------|---------|
| `RET-` | Returns logistics | `RET-STATE-01` |
| `REF-` | Refunds | `REF-BRIDGE-01` |
| `CON-` | Customer contacts / support | `CON-GRAIN-01` |
| `MER-` | Merchandising | `MER-SKU-01` |
| `CAT-` | Catalog discovery (cross-domain) | `CAT-DBC-01` |

## File lifecycle (SQL)

```
sql/open/      ← live queue (not yet run)
sql/answered/  ← ran, verdict recorded in docs/03
sql/archive/   ← superseded, never run
```

## Verdict taxonomy (docs/03 annotations)

- `CONFIRMED` — finding verified by data with row counts / percentages
- `FLAG` — anomaly noted, not blocking, documented for future handling
- `BLOCKER` — blocks downstream work until resolved

## Naming

- CSV outputs: `data/profiling_results/<ID>_<short_name>.csv`
- SQL `@name` markers must match the ID: `/* @name RET-STATE-01_reconstruction */`
- Domain layer artifacts: `layers/data_layer/tier{1,2,3}_*/`

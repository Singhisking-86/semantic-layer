# NB-OS Layers

Four-layer NB-OS stack. See `../docs/00_vision_target_architecture.md` for the
full description. Dependency direction: Application & Intelligence consume the
**Data layer**; the **Infrastructure & Integration layer** runs everything and is
the only layer that writes to N Brown operational systems.

| Folder | Layer | Status |
|--------|-------|--------|
| `data_layer/` | Data layer — semantic model for returns/refunds, engine-agnostic | **ACTIVE FOCUS.** Being authored now (Teradata for exploration; Databricks later). |
| `infra_integration_layer/` | Databricks impl, AO scheduling, service deployment, action initiation | DEFERRED — placeholders only. |
| `intelligence_layer/` | insight discovery, problem analysis, action recommendation, impact assessment | DESIGNED — placeholders; build after Data layer stable. |
| `application_layer/` | 24×7 reporting, constant optimization (HIL+agentic), conversational | DESIGNED — placeholders. |

The Data layer is the deliverable in flight. Its three tiers map to subfolders:
- `data_layer/tier1_ontology/` — process ontology (business vocabulary; no source names)
- `data_layer/tier2_contracts/` — canonical schemas, `metric_registry/`, agent-readable `catalog/`
- `data_layer/tier3_bindings/` — declarative source→contract mappings + load rules (only tier that knows Teradata/Databricks)

Evidence and SQL that *feed* the Data layer still live at the repo root
(`docs/`, `sql/`, `data/`, `reference/`); the `layers/` tree holds the
**designed artifacts**, not the discovery work.

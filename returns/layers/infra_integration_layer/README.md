# Infrastructure & Integration layer (DEFERRED)

Not built now. Design lives in ../../docs/00_vision_target_architecture.md.
When built, this layer provides: Databricks implementation of the Data layer;
always-on (AO) production refresh (daily/hourly/TBD) honouring rule R7 watermarks;
deployment of the Intelligence and Application services; and the only write path
that initiates actions on N Brown operational systems (under the HIL→agentic
promotion ladder).

Subfolders are placeholders:
- `databricks/`        — ingestion + transform implementation of tier-3 bindings; tier-2 as governed tables/metric store; catalog published to Unity Catalog
- `orchestration/`     — schedules, watermarks, AO health, "data as of"
- `deployment/`        — packaging/CI/CD for NB-OS services
- `action_initiation/` — connectors that execute approved actions on operational systems

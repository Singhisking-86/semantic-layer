# Application layer (TARGET DESIGN)

Placeholders. Consumes the Data layer; surfaces generated FROM the metric registry
so reporting and conversational answers cannot diverge. Design in
../../docs/00_vision_target_architecture.md.

- `reporting/`       — 24×7 operational analytics, rendered from the metric registry; shows "data as of" + DQ SLO status
- `optimization/`    — recommendation service embedded in workflows (HIL queue first; agentic for ladder-promoted actions)
- `conversational/`  — ad hoc problem-solving agent sessions grounded in the semantic catalog

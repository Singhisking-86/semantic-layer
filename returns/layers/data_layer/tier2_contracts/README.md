# Tier 2 · Semantic Contracts (ACTIVE)

Canonical logical schemas + metrics-as-code + agent-readable catalog + DQ SLOs.
Definitions expressed against tier-1 concepts; engine-neutral.

- canonical entities: return_request_line, return (header), tracking_event
  (unified), wh_item_event, refund_event, return_state_transition, conformed
  calendar — see docs/04 for grains and derivation.
- `metric_registry/` — one versioned spec per metric (id, version, owner,
  plain-English definition, tier-1 derivation, caveats, calibration target).
- `catalog/` — the agent-readable surface: every entity + metric with definition,
  derivation, caveats, freshness. Generated/maintained here.

# Tier 1 · Process Ontology (ACTIVE)

Source-agnostic business model for returns/refunds (later customer contacts).
Business vocabulary ONLY — no column names, no system names. Authored from
docs/01 (decision log / business flow) and docs/04 (state model), validated by
the P/Q evidence.

Planned artifacts (author as the model firms up):
- `returns_ontology.md` — entities (Return=parcel, ReturnRequestLine, Refund,
  RefundMethod...), lifecycle states ①–⑤, status definitions, policies
  (10-day SLA ②→④, refund auto-trigger on ④, card +5d), controlled vocabulary
  (reason groups: Buying/Customer Choice/Delivery-Warehouse/Fit/Quality).
- `glossary.md` — every business term, one plain-English definition each.

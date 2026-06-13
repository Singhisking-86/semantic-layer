# Contacts — Cross-Domain Contact Events (STUB)

**Status: Not started.** This domain captures the cross-domain interaction layer
between customer contacts and other operational events (returns, orders, refunds).
Distinct from customer-support/ which models the contact centre semantic layer —
this folder holds the joined, cross-domain view.

## Scope (planned)

- Contact-to-event linkage: which contacts are associated with which return /
  order / refund events
- Timeline reconstruction: contact sequence relative to return state transitions
- SQL ID namespace: `CON-` (shared with customer-support — coordinate IDs)

## When to activate

After both returns and customer-support domains have stable tier 2 contracts.

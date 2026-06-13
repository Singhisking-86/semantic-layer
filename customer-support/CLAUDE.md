# Customer Support — Semantic Layer (STUB)

**Status: Not started.** This domain will model N Brown customer contact events —
inbound contacts, contact reasons, resolution outcomes, and their relationship to
orders, returns, and refunds.

## Scope (planned)

- Contact grain: one row per contact event (call, chat, email, web form)
- Key entities: Contact, ContactReason, ResolutionOutcome, Agent
- Cross-domain links: Contact → Order (via order number), Contact → Return (via
  return ID where contact is returns-related)
- Shared entities: Customer (defined in `../shared/ontology.md`)

## SQL ID namespace

`CON-` prefix. Register all questions in `sql/REGISTER.md` when work begins.

## When to activate

After returns Phase 2 (semantic contracts) is delivered. Do not start profiling
until the returns state model is stable — contact data references return IDs.

# Merchandising — Semantic Layer (STUB)

**Status: Not started.** This domain will model product, range, and inventory
semantics — SKU attributes, range planning, availability, and their relationship
to returns and demand signals.

## Scope (planned)

- Product grain: SKU / style / colour / size hierarchy
- Key entities: Product, Range, Category, Supplier
- Cross-domain links: Product → OrderLine (via SKU), Product → ReturnReason
  (return rate by product)
- Shared entities: Order, OrderLine (defined in `../shared/ontology.md`)

## SQL ID namespace

`MER-` prefix. Register all questions in `sql/REGISTER.md` when work begins.

## When to activate

After returns Phase 1 closes — return-rate-by-product is an early cross-domain
use case that will drive initial merchandising profiling scope.

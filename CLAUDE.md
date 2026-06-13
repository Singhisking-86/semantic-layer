# Semantic Layer Platform — Root Conventions

This repo is the single home for all semantic layer domains. Each domain is a
self-contained subfolder with its own CLAUDE.md. This root file defines only
what is shared across every domain — read it, then read the domain CLAUDE.md
for active context.

## Domains

| Folder | Status | Description |
|--------|--------|-------------|
| `returns/` | ACTIVE | N Brown returns & refunds — Phase 1 ~80% complete |
| `customer-support/` | STUB | Customer contact semantic layer — not started |
| `merchandising/` | STUB | Merchandising semantic layer — not started |
| `contacts/` | STUB | Cross-domain contact events — not started |

## Shared resources

- `shared/ontology.md` — enterprise entity glossary (Customer, Order, Product,
  Return, Contact). Add an entity here only when two or more domains share it.
- `shared/conventions.md` — ID schemes, naming rules, file lifecycle rules that
  apply across all domains.

## Cross-domain interaction protocol

- Domain A never imports domain B's source bindings directly. Cross-domain joins
  happen at tier 2 (semantic contracts) via shared entities in `shared/ontology.md`.
- When a concept appears in two domains, define it once in `shared/` and reference
  it from each domain's tier 1 ontology. Do not duplicate.
- Each domain's SQL ID namespace is isolated: `RET-`/`REF-` (returns),
  `CON-` (contacts/customer-support), `MER-` (merchandising), `CAT-` (catalog
  discovery — cross-domain). Never reuse an ID across domains.

## Adding a new domain

1. Create `<domain>/` folder
2. Copy the stub `CLAUDE.md` from an existing stub domain and fill in scope
3. Add a row to the table above
4. Add shared entities to `shared/ontology.md` only if another domain already
   uses them

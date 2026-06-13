# semantic-layer

Semantic layer platform — decoupled, evidence-grounded semantic models for N Brown operational domains.

## Structure

```
semantic-layer/
├── shared/              # Cross-domain ontology and conventions
├── returns/             # Returns & refunds — ACTIVE
├── customer-support/    # Customer contact semantic layer — STUB
├── merchandising/       # Merchandising semantic layer — STUB
└── contacts/            # Cross-domain contact events — STUB
```

## How to navigate

- **New to this repo:** read `CLAUDE.md` (root) then the domain `CLAUDE.md` you are working in
- **Working on returns:** `cd returns/` — all active work, SQL, docs, and data are there
- **Adding a domain:** see the "Adding a new domain" section in root `CLAUDE.md`

## Tech

- Python 3 + `teradatasql` + pandas (returns profiling)
- SQL (Teradata dialect)
- Markdown + YAML (semantic artifacts)

## Setup

```bash
cd returns
cp .env.example .env    # fill in Teradata credentials
pip install -r requirements.txt
```

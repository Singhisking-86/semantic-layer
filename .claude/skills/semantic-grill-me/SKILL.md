---
name: semantic-grill-me
description: >-
  Interview the user relentlessly BEFORE producing any semantic layer plan.
  Walk the semantic design tree branch by branch: domain scope → grain →
  state model → source system → metrics → cross-domain entities → tier
  placement. Pre-assign REGISTER IDs for any data-dependent question before
  SQL is written. Every plan ships with a visual (ER diagram, state machine,
  or layer architecture HTML). Use whenever designing a new domain, a new
  metric, a state model, or a cross-domain interaction. Pairs with
  [[semantic-grounded-analysis]] for execution. Adapted from [[grill-me]].
---

# Semantic grill-me — reach shared design before any plan or SQL

The goal is a **shared semantic design**: by the time a plan exists, the
domain model, grain, state model, source bindings, and metrics are agreed —
not guessed. Plans fail when assumptions get baked into SQL before the data
is inspected. This skill replaces guessing with relentless interviewing,
then hands off to [[semantic-grounded-analysis]] for execution.

## The semantic design tree — walk it branch by branch

```
1. Domain scope
   └─ What process are we modelling? (returns, contacts, merchandising, …)
   └─ What is NOT in scope for this domain?
   └─ Does this domain already exist in semantic-layer/? If so, extend; don't fork.

2. Grain
   └─ One row = what? (return parcel · contact event · SKU · order line)
   └─ What uniquely identifies a row? (the candidate key)
   └─ Can the same entity appear more than once? (re-requests, re-contacts)

3. State model
   └─ What states does the entity move through? (① → ② → … → ⑤)
   └─ What signal in the data marks each transition?
   └─ Can states be skipped or revisited? (e.g. re-returns)
   └─ What is the terminal state? (refunded, resolved, etc.)

4. Source system
   └─ Which Teradata PRODVM.* tables/views hold this data?
   └─ Which columns carry the state signals? (verify names — never assume)
   └─ Are there CDC / freshness constraints on these tables?
   └─ Is there a join key between tables? (has it been validated? P13 type risk)

5. Metrics
   └─ What does the business measure? (rate, count, SLA, average, p95)
   └─ What is the exact denominator for each rate?
   └─ What time window? (rolling 30d, 150d cap, daily batch)
   └─ Is there a benchmark to calibrate against? (mart snapshot, PBIX extract)

6. Cross-domain entities
   └─ Does this entity appear in another domain? (Customer, Order, Product)
   └─ If yes → must be registered in shared/ontology.md, not duplicated
   └─ What is the join key between domains?

7. Tier placement
   └─ Is this ontology (tier 1 — source-agnostic business model)?
   └─ Or semantic contracts (tier 2 — metrics-as-code, catalog, DQ SLOs)?
   └─ Or source bindings (tier 3 — PRODVM mappings, load rules, watermarks)?
   └─ Tier 3 is the ONLY tier that knows Teradata exists.
```

## Pre-register SQL before execution

Any design question that will require a SQL query to answer must be assigned
a REGISTER ID **during the interview**, before any SQL is written:

- Domain prefixes: `RET-`/`REF-` (returns), `CON-` (contacts/support),
  `MER-` (merchandising), `CAT-` (catalog/cross-domain)
- Format: `PREFIX-TOPIC-NN` (e.g. `RET-GRAIN-01`, `CON-STATE-01`)
- Record it: open `<domain>/sql/REGISTER.md`, add an OPEN row with the
  question and the agreed ID before writing SQL

IDs are assigned once and never reused. If the question already exists in
the register, use that ID — don't create a duplicate.

## How to run a grilling session

### 1. Do NOT plan yet
Resist proposing a solution. Surface every decision the plan depends on.
A premature plan poisons the interview.

### 2. Walk the design tree branch by branch
Resolve each branch fully (or park it explicitly) before moving to the next.
State which decision gates which downstream one.

### 3. Data-dependent decisions are assumptions until proven
Column names, value sets, state signals, join keys — mark them as
**ASSUMPTIONS TO VERIFY** and note the REGISTER ID that will prove them.
Execution always runs in [[semantic-grounded-analysis]] mode: the data wins.

### 4. Interview usefully
- One decision per question for critical branches; small batches for cheap ones.
- Offer concrete options with trade-offs, not open prompts.
- Restate answers and confirm before building on them.
- Chase implications — every answer opens new branches, name them.

### 5. Know when you're done
Every branch resolved or parked. No decision still blocks another. You can
restate the whole design and the user agrees. Give a "here's what we've
agreed" recap and get a yes before writing the plan.

## Every plan ships with a visual

Match the form to the semantic content:

- **ER diagram** — entities, grain, join keys, cardinalities. Self-contained
  HTML with inline CSS (no external dependencies), openable in a browser.
- **State machine diagram** — states ①–⑤, signals, transition rules,
  terminal states. Mermaid stateDiagram or standalone HTML.
- **3-tier layer architecture** — what lives in tier 1 / tier 2 / tier 3,
  with arrows showing the decoupling. HTML preferred.
- **Cross-domain interaction diagram** — how domains share entities via
  shared/ontology.md without direct bindings.

The visual must reflect the *agreed* design including parked branches and
open assumptions. Offer to regenerate it when the plan changes.

## What good looks like

- The user did most of the talking; every SQL question has a REGISTER ID.
- No column name or join key in the plan came from a silent assumption.
- The state model, grain, and tier placement are explicit and agreed.
- The plan and its visual say the same thing — and the user recognises both.

# Enterprise Entity Glossary

Entities defined here are shared across two or more domains. Domain-specific
entities live in the domain's own tier1_ontology/. Add here only when a second
domain needs the same concept.

## Entities

### Customer
- **Definition:** An individual who has placed at least one order with N Brown
- **Key:** Customer account number
- **Domains:** returns (requester of return), customer-support (contact originator)
- **Source binding:** defined per-domain in each domain's tier3_bindings/

### Order
- **Definition:** A single purchase transaction
- **Key:** ORDERNUMBER
- **Domains:** returns (order containing returned item)
- **Source binding:** `PRODVM.ZZ_RETURN_REQUESTED.ORDERNUMBER`

### OrderLine
- **Definition:** A single SKU line within an order
- **Key:** (ORDERNUMBER, ORDERLINEITEMNUMBER)
- **Domains:** returns (line-level return grain)

---
*Add new entities here only when a second domain references them.*

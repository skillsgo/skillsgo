---
status: superseded by ADR-0010 and ADR-0011 before public launch
---

# Freeze the Hub v1 distribution contract

ADR-0010 replaces the rejected per-Skill artifact model with one immutable artifact, version, ZIP, Sum, download, lock, and Vendor unit per Repository Version. ADR-0011 identifies selectable members by Repository ID plus canonical Skill Name and keeps Skill Path as immutable release metadata.

The repository had not launched when these decisions changed. No compatibility route, parser, alias, data migration, or legacy artifact reader is retained. ADR-0010 and ADR-0011 are the only normative contracts for the current design.

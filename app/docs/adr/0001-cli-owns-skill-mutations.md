---
status: superseded by system ADR-0001
---

# The CLI Owns Skill Mutations

The original MVP delegated installation, update, and removal to an external `skills` CLI while Flutter handled orchestration, feedback, and read-only presentation. The durable part of this decision is preserved by system ADR-0001: Flutter must not grow a second local package-management engine. The external CLI dependency itself is superseded.

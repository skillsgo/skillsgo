---
status: superseded by ADR-0010 before public launch
---

# Separate module and API surfaces

ADR-0010 supersedes this proposal before public launch. The accepted architecture keeps product APIs under `/api/v1`, exposes the Artifact Origin itself as the Repository Proxy Base, and uses `skillsgo.yaml` plus generated `skillsgo-lock.yaml` for local state.

No route, parser, file-name alias, or migration from this rejected design is implemented. See ADR-0010 for the complete current contract.

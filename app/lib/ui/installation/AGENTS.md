# Installation Journeys
> F3 | Parent: `/app/lib/ui/AGENTS.md` | Workspace: `skillsgo`

## Members

- `detail_primitives.dart`: renders remote-detail identity, evidence, Markdown, files, shared skeleton primitives, and direct Installation submission for the user-selected Package version.
- `installation_scope_panel.dart`: loads and selects explicit location-and-Agent targets for a direct Installation Request and renders reduced-motion-safe installed-target detail expansion.
- `installation_target_detail.dart`: renders installed-target health, scope, Agent, and version diagnostics.
- `remote_detail_core.dart`: owns remote-detail lifecycle, loading, retry, and install-operation coordination.
- `remote_detail_rendering.dart`: renders remote-detail content, failures, risk, and action state.
- `target_management_dialog.dart`: confirms and executes removal of every preflight-authorized managed Package-member or exact External Installation target.

## Architectural Boundary

This module owns rendered installation, update, and target-management workflows. It receives intent through typed gateway and controller interfaces; it must not invent targets, collapse target-specific results, or access processes and files directly.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md

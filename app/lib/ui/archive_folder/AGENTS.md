# Archive Folder/
> F3 | Parent: `/app/lib/ui/AGENTS.md` | Workspace: `skillsgo`

## Members

- `archive_folder.dart`: preserves Portal Labs Archive Folder geometry, glass front flap, horizontal and vertical layouts, staggered reveal, haptics, and pop-to-front behavior, while adding structured front copy, the `frontChild` extension, opt-out toggle interaction for embedded controls, and an optional minimum canvas extent for cross-folder scale alignment.
- `archive_folder_style.dart`: unmodified upstream visual, geometry, animation, and orientation configuration; vendored source is exempt from F4.
- `archive_item.dart`: preserves the upstream archival frame while adding opt-in fixed label height and line clamping for compact product cards.

## Architectural Boundary

This module owns the vendored Folder visual and interaction primitive. Product-specific copy, physics, colors, and item content must be composed by consumers rather than changing upstream geometry or styling. Any upstream-derived change must preserve attribution and keep deviations explicit in this map.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md

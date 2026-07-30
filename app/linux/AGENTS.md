# Linux Desktop Integration/
> F3 | Parent: `../AGENTS.md` | Workspace: `skillsgo`

## Members

- `CMakeLists.txt`: configures the Linux Flutter bundle, native CLI build, plugin compatibility, and runtime resource installation.
- `runner/CMakeLists.txt`: builds the GTK runner executable and declares its native dependencies.
- `runner/main.cc`: starts the GTK application.
- `runner/my_application.h`: exposes the native application type and constructor.
- `runner/my_application.cc`: creates the GTK window, loads the bundled application icon, hosts Flutter, and registers plugins.
- `runner/resources/skillsgo.png`: provides the installed Linux application and window icon.
- `flutter/`: contains Flutter-managed Linux build integration and generated plugin registration.

## Architectural Boundary

This module owns Linux desktop startup, native packaging, and relocatable bundle integration. It must not own Flutter product behavior or local package-management operations beyond bundling the CLI executable.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md

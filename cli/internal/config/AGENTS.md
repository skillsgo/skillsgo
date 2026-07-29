# User Configuration Module
> F3 | Parent: `/cli/AGENTS.md` | Workspace: `github.com/skillsgo/skillsgo/cli`

## Members

- `config.go`: owns strict, versioned, atomic `~/.skillsgo/config.yaml` persistence and its current canonical-path-only `projects` configuration section.
- `config_test.go`: specifies strict YAML parsing, minimal canonical project paths, idempotent registration, removal, and preservation of the shared configuration document.

## Architectural Boundary

This module is the sole owner of the user-level SkillsGo configuration document. It may expose typed operations over configuration sections, but it must not inspect Workspace declarations, mutate Package state, scan for Workspaces, or own App presentation metadata.

[PROTOCOL]: Update this header when this file changes, then review AGENTS.md

# ADR-0023: Bootstrap Projects from Local Agent Sessions

## Status

Accepted

## Context

The App previously required a Personal User to select every Added Project through a directory picker before project-scoped Skill management became useful. Claude Code and Codex already retain local session metadata containing the Workspace current directory, so a clean installation can recover recent real project roots without crawling broad filesystem locations or reading prompt content.

Automatically repeating that discovery would conflict with project removal: a Workspace deliberately removed from SkillsGo could reappear while an old Agent session remained inside the discovery window.

## Decision

The CLI exposes `skillsgo project bootstrap`. Before the configuration's one-time project-bootstrap marker is set, the command:

- reads only bounded local Claude Code and Codex session metadata;
- considers sessions active within the previous thirty days;
- extracts only Workspace `cwd` and filesystem modification time;
- excludes the user home, missing roots, and non-directories;
- canonicalizes and deduplicates before selecting at most twelve Workspaces by recent activity;
- atomically persists those roots in the ordinary deterministic path-sorted `projects` sequence.

Bootstrap atomically sets its durable marker even when no project is discovered. An explicit project add also sets that marker. Once marked, bootstrap performs no discovery and returns the existing projects unchanged. The App invokes bootstrap before loading Added Projects. Afterward, `project add` and `project remove` remain the only operations that change the sequence.

Session prompts, responses, file names, and project content are outside this operation. Bootstrap remains local and does not report discovered paths to the Hub.

This decision supersedes ADR-0015 only where that ADR requires every project registration to be explicit and forbids inference from recent directories. It preserves ADR-0015's CLI-owned configuration, canonical project paths, and removal semantics.

## Consequences

- A clean App starts with relevant project-scoped Library locations without repetitive directory selection.
- Removing a project remains durable, including removal of the last project, because the bootstrap marker is independent of sequence emptiness.
- Agent session formats are local adapters and may fail independently without preventing startup or explicit project management.

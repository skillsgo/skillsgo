# skills.sh Behavior Compatibility Matrix

Verified against the local `skills-sh` and SkillsGo worktrees on 2026-07-17.

## Purpose

This matrix treats skills.sh tests as a behavior-requirement pool rather than
source code to translate. SkillsGo intentionally preserves selected filesystem
contracts while adding Store integrity, deterministic declarations and locks,
atomic replacement, and explicit target-health semantics.

Status meanings:

- **Covered**: an executable Go test directly specifies the behavior.
- **Partial**: the core behavior is tested, but a platform, scope, or CLI seam
  remains uncovered.
- **Not applicable**: the behavior belongs to a skills.sh-only command or data
  model and is intentionally not part of SkillsGo.

## Priority topology contracts

| Behavior contract | Status | SkillsGo executable evidence | Notes |
| --- | --- | --- | --- |
| Project installation materializes `.agents/skills/<skill>` as a physical directory | Covered | `internal/install/installer_test.go` — `TestInstallSharedPhysicalTargetMaterializesOnce`, `TestInstallMaterializesCanonicalAndLinksAgentSpecificTarget` | Prevents canonical self-links. |
| User installation materializes `~/.agents/skills/<skill>` as a physical directory | Covered | `internal/install/installer_test.go` — `TestInstallUserScopeMaterializesHomeCanonicalAndAgentProjection`; `internal/install/target_test.go` — `TestResolveProjectAndUserTargets` | User and project roots are independent. |
| Agent-specific directories link to the scope canonical | Covered | `internal/install/installer_test.go` — project and user projection tests | Link identity is checked against canonical content. |
| Copy mode writes a physical Agent target and does not materialize canonical content | Covered | `internal/install/installer_test.go` — `TestSkillsSHCompatibilityCopyPreservesDotfilesAndExecutableMode` | Also mirrors skills.sh dotfile and executable-mode contracts. |
| Multiple Agents share one physical canonical copy | Covered | `internal/install/installer_test.go` — `TestInstallSharedPhysicalTargetMaterializesOnce`; `internal/plan/plan_test.go` — `TestExecuteRecordsEveryAgentWhenTargetsShareOnePhysicalCopy` | Logical bindings remain separate. |
| Updating canonical content preserves Agent projections | Covered | `internal/install/update_test.go` — `TestReplaceUpdatesCanonicalAndKeepsAgentProjectionLinked` | Projection remains a symlink to the replaced canonical directory. |
| Removing one projection cannot remove canonical content still used by another binding | Covered | `internal/install/installer_test.go` — `TestRemoveRetainsSharedCanonicalUntilLastBindingIsRemoved` | Removal executes projections before canonical targets. |
| Removing the last binding removes canonical content according to the declared lifecycle | Covered | Same removal test | Store artifacts remain outside this lifecycle. |
| Legacy Agent links directly to Store are rejected | Covered | `internal/install/installer_test.go` — `TestRemoveRejectsLegacyAgentLinkDirectlyToStore`; `internal/inventory/health_test.go` | No automatic backward-compatible migration is performed. |
| A new machine restores the same multi-Agent topology from manifest and lock | Covered | `internal/command/install_flow_test.go` — offline, clean-Store, and repository dependency restore tests | Covers offline Store recovery, an initially empty Store refilled from Hub, multiple repository packages, and complete installation-tree comparison. |
| Inventory classifies broken links, replaced targets, modified canonical content, and legacy Store links | Covered | `internal/inventory/health_test.go` — `TestManagedTargetHealthClassifiesCanonicalAndProjectionDamage` | Includes missing, dangling, modified, directory replacement, and Store-direct link states. |
| Project and user scopes never resolve into each other's roots | Covered | `internal/install/target_test.go` — `TestResolveProjectAndUserTargets`; user/project materialization tests | Target resolution and filesystem materialization are both covered. |

## Broader skills.sh behavior pool

| skills.sh behavior family | SkillsGo disposition | Evidence or remaining gap |
| --- | --- | --- |
| Repeated identical install skips or reconciles without destructive replacement | Covered | Installation Plan skip and retry tests in `internal/plan/plan_test.go`. |
| Existing real directory is not silently overwritten | Covered | `TestInstallDoesNotOverwriteExistingTarget` and explicit replacement-plan tests. |
| Canonical and Agent paths that coincide do not create self-loop symlinks | Covered | Physical canonical tests plus target-resolution tests. |
| Parent Agent directory is itself a symlink | Covered | `internal/install/installer_test.go` — `TestInstallAndRemoveProjectionWhenAgentSkillsParentAliasesCanonicalParent`; inventory health matrix | Prevents child self-links and canonical deletion through an aliased parent. |
| Update failure rolls back earlier filesystem replacements | Covered | `TestReplaceRollsBackEarlierTargetWhenLaterTargetFails`. |
| Lock output is deterministic and preserves unrelated dependencies | Covered | Project file upsert, merge, collapse, and remove-binding tests. |
| Corrupt or conflicted lock input is silently treated as empty | Not applicable | SkillsGo treats manifest/lock corruption as an explicit unreadable/error state rather than discarding it. |
| Source discovery from `node_modules` and `experimental_sync` | Not applicable | SkillsGo does not implement the skills.sh experimental npm sync command. |
| CLI aliases, prompt wording, interactive selection, and Node-specific errors | Not applicable | These are interface and implementation details, not selected compatibility contracts. |
| Case-insensitive name-based bulk removal | Not applicable | SkillsGo management operations are state-bound and target-exact. |
| Windows symlink privilege/fallback behavior | Partial | Copy behavior is portable; real Windows CI coverage for projection creation and failure classification remains to be added. |
| Static Discovery Root visibility | Covered | Inventory v5 derives Agent visibility from installed-Agent Discovery Roots and physical target identity without creating managed Targets. Runtime-configured roots and ancestor traversal remain future inputs. |

## Remaining priorities

1. Run projection lifecycle tests on Windows CI and define whether unavailable
   symlink privilege is a hard failure or an explicit copy fallback.
2. Add runtime-configured and ancestor-walking Discovery Root providers without
   converting read-only visibility into managed Installation Targets.

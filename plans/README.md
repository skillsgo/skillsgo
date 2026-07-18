# Animation Improvement Plans

Plans in this directory are read-only audit outputs produced against the
recorded commit. Execute them in order unless a plan documents a dependency.

| Number | Plan | Severity | Status | Dependencies |
| --- | --- | --- | --- | --- |
| 001 | [Animate the Library selection toolbar](001-animate-library-selection-toolbar.md) | MEDIUM | DONE | None |

## Recommended execution order

1. Execute plan 001. It is isolated to the Library bulk-selection surface and
   has no dependency on another motion change.

## Execution

Use `improve-animations execute <plan>` with the plan path, or hand the plan to
an implementation agent. The executor must honor the stamped commit, scope
boundaries, reduced-motion behavior, and verification checklist.

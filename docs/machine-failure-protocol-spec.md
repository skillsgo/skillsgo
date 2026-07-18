---
status: implemented
---

# SkillsGo CLI Machine Failure Protocol

## Purpose

Define the first stable machine-failure contract for the bundled App, CI/CD, and developer automation. This specification implements the failure-protocol portion of [ADR 0005](adr/0005-route-app-through-cli-and-stabilize-machine-failures.md). The numbered requirements are normative; the single worked example is supplementary.

## Normative Requirements

### 1. System Boundary

1.1. The App must use the bundled CLI as its only business-integration boundary.

1.2. The App must not call a Hub directly.

1.3. Hub HTTP status, response text, transport errors, and internal causes must terminate at the CLI Hub adapter and be translated into CLI machine failures.

1.4. This delivery defines failure transport only. Adding the CLI commands needed to migrate every existing App Hub-backed read is a separate implementation scope.

### 2. Machine Output Selection

2.1. `--output json` selects one complete JSON result document on stdout.

2.2. `--output ndjson` selects a sequence in which every stdout line is one complete JSON document.

2.3. Once the CLI has recognized JSON or NDJSON mode, both success and failure results must use the selected stdout format.

2.4. If argument parsing fails before the CLI can reliably recognize machine mode, the CLI may retain conventional stderr-only usage failure.

2.5. Machine stdout must not contain color, animation, progress control sequences, or localized prose required for caller behavior.

2.6. stderr may contain Human diagnostics but is not part of the machine contract.

### 3. Early Failure Document

3.1. A recognized JSON-mode failure that occurs before a normal result exists must write exactly one document of this shape to stdout:

```json
{
  "schemaVersion": 1,
  "phase": "error",
  "error": {
    "code": "hub.unavailable",
    "retryable": true
  }
}
```

3.2. A recognized NDJSON-mode failure must write the same `phase: "error"` document as its final stdout line after any valid progress documents.

3.3. A command that writes a completed execution document with failed targets must not append a redundant early failure document.

### 4. Error Object

4.1. Every machine failure object must contain:

- `code`: a stable, language-neutral domain code;
- `retryable`: whether retrying the same user intent is a supported recovery path, possibly after obtaining fresh preflight state.

4.2. A machine failure object may contain:

- `details`: structured values needed to identify the affected resource or render caller-owned copy;
- `requestId`: a Hub correlation identifier when one is available;
- `diagnostic`: unstable developer text.

4.3. `diagnostic` must not be parsed, used to choose behavior, or displayed as default App product copy.

4.4. `diagnostic` may contain paths inside the user's requested operation scope but must not contain credentials, tokens, Hub internal stack traces, or secrets.

4.5. Callers must ignore unknown additive fields.

4.6. An unknown `code` must produce generic caller-owned failure presentation and must not make an otherwise valid document malformed.

4.7. HTTP status, Go error types, filesystem errno values, and localized messages must not become public error codes.

### 5. Target Result Format

5.1. Installation, update, and management execution documents must retain complete per-target results and a summary.

5.2. A failed target must contain one nested `error` object using Section 4.

5.3. A succeeded or idempotently skipped target must omit `error`.

5.4. When a document advances to the nested error object, legacy parallel `errorCode` and `diagnostic` fields must not remain as a second authoritative representation.

5.5. The Installation Plan execution schema must advance from `2` to `3` for this breaking target-result shape change.

### 6. Mutation Semantics

6.1. One Installation Target Group is the atomic compensation scope.

6.2. If a member of an Installation Target Group or its associated Workspace persistence fails, that group must roll back or restore its prior state.

6.3. Unrelated Installation Target Groups in the same Installation Request must continue independently and remain committed when they succeed.

6.4. Update and management operations must preserve their existing independent target-group semantics.

6.5. The complete final execution document must report every requested target, including committed successes and compensated failures.

### 7. Exit Status

7.1. Exit `0` means every requested mutation target succeeded or reached an idempotent successful skip state.

7.2. `add`, `update`, and `manage` must return non-zero when any requested target failed, conflicted, was risk-blocked, or had stale reviewed state.

7.3. A mutation command must write its complete structured result before returning its non-zero status.

7.4. A non-zero status must not roll back already committed unrelated target groups.

7.5. Exit `69` continues to represent Hub unavailability.

7.6. Exit `75` continues to represent temporary timeout or rate-limit failure.

7.7. Other failures use the existing general failure status unless an existing stable process status applies.

7.8. Exit status is authoritative for shell success or failure; structured stdout is authoritative for target identity and detailed outcomes.

### 8. Localization

8.1. Error codes, retryability, detail keys, and request IDs must remain language-neutral.

8.2. CLI Human mode must map typed failures to CLI-owned localized terminal copy.

8.3. CLI machine mode must not require a locale.

8.4. The App must map stable codes and details to App-owned ARB copy and recovery actions.

8.5. The App must not parse stderr or display it as default error copy.

8.6. The App may expose `diagnostic` only in an explicit diagnostic surface.

### 9. Compatibility

9.1. The bundled App and CLI must continue to use the existing exact `appProtocolVersion` startup handshake.

9.2. `appProtocolVersion` is `9`, incremented from `8` when the App began depending on this contract.

9.3. Human terminal output is not a versioned parsing interface and may evolve independently.

9.4. Machine callers may reject missing required fields or unsupported schema versions.

### 10. Scope Limits

10.1. This delivery must implement:

- structured failure output after machine mode is recognized;
- stable nested target failures for installation, update, and management;
- consistent non-zero mutation exit status;
- typed App translation without stderr parsing.

10.2. This delivery must not introduce:

- a shared App, CLI, and Hub source-code error package;
- error categories, nested causes, severity, documentation URIs, or a registry framework;
- a redesign of Hub internal errors or all Hub endpoint envelopes;
- version-range negotiation beyond `appProtocolVersion`;
- a global transaction across unrelated Installation Target Groups.

## Initial Stable Codes

A new code is justified only when App or automation callers require a different recovery action or stable decision. Internal causes with identical caller behavior share one public code.

| Code | Default retryability | Caller meaning |
| --- | --- | --- |
| `input.invalid` | false | Correct the command or structured request. |
| `hub.unavailable` | true | Retry a Hub-dependent operation later. |
| `hub.timeout` | true | Retry after a dependency timeout. |
| `hub.rate_limited` | true | Retry according to Hub availability guidance. |
| `protocol.invalid_response` | true | Retry or diagnose a malformed dependency response. |
| `protocol.incompatible` | false | Upgrade the incompatible caller, CLI, or dependency. |
| `local.data_invalid` | false | Repair or inspect untrusted local SkillsGo state. |
| `installation.state_changed` | true | Obtain fresh preflight state before retrying. |
| `installation.target_failed` | true | Retry one compensated Installation Target Group. |
| `workspace.persistence_failed` | true | Fix Workspace access if needed, then retry the compensated group. |
| `update.target_failed` | true | Retry one independent update group. |
| `management.target_failed` | true | Retry one independent management action. |
| `internal.unexpected` | false | Use diagnostics; no automatic recovery is promised. |

## Supplementary Worked Example

### Scenario

A user installs `github.com/acme/skills/-/review` at immutable version `v1.2.3` into two independent Installation Target Groups:

- the Codex User Scope target succeeds;
- the Claude Code Workspace target is materialized in `/work/project`, but writing `/work/project/skillsgo.mod` fails, so that target group is compensated and reported as failed.

### Input

The caller starts the CLI without shell interpolation. The following display is line-wrapped only for documentation; the executable and every argument are separate process arguments.

```text
skillsgo add github.com/acme/skills/-/review
  --skill review
  --target {"scope":"user","agent":"codex","mode":"symlink"}
  --target {"scope":"project","projectRoot":"/work/project","agent":"claude-code","mode":"symlink"}
  --version v1.2.3
  --yes
  --output json
  --hub https://hub.skillsgo.ai
```

Each `--target` value is one strict JSON object. Unknown fields and trailing JSON values are invalid.

### Data Flow

```text
App or CI caller
  -> CLI command boundary validates source, version, and exact targets
  -> CLI Hub adapter reads immutable Info and ZIP resources
  -> CLI verifies artifact identity, archive size, and Content Digest
  -> Installation Plan builds two independent target groups
  -> Codex User Scope group commits
  -> Claude Code Workspace group materializes
  -> skillsgo.mod persistence fails
  -> CLI compensates only the failed Workspace group
  -> CLI writes one complete execution document to stdout
  -> CLI may write unstable diagnostics to stderr
  -> CLI exits non-zero
  -> App parses stdout and renders App-owned localized recovery
```

The CLI Hub adapter performs the required immutable protocol requests, such as:

```text
GET /mod/github.com/acme/skills/-/review/@v/v1.2.3.info
GET /mod/github.com/acme/skills/-/review/@v/v1.2.3.zip
```

The App never performs these requests.

### Stdout

```json
{
  "schemaVersion": 3,
  "phase": "execution",
  "artifact": {
    "source": "github.com/acme/skills/-/review",
    "skillId": "github.com/acme/skills/-/review",
    "version": "v1.2.3",
    "name": "review",
    "risk": "low"
  },
  "results": [
    {
      "target": {
        "scope": "user",
        "agent": "codex",
        "mode": "symlink",
        "path": "/Users/example/.codex/skills/review",
        "canonicalPath": "/Users/example/.agents/skills/review"
      },
      "action": "create",
      "outcome": "succeeded"
    },
    {
      "target": {
        "scope": "project",
        "projectRoot": "/work/project",
        "agent": "claude-code",
        "mode": "symlink",
        "path": "/work/project/.claude/skills/review",
        "canonicalPath": "/work/project/.agents/skills/review"
      },
      "action": "create",
      "outcome": "failed",
      "error": {
        "code": "workspace.persistence_failed",
        "retryable": true,
        "details": {
          "path": "/work/project/skillsgo.mod"
        },
        "diagnostic": "open /work/project/skillsgo.mod: permission denied"
      }
    }
  ],
  "summary": {
    "succeeded": 1,
    "skipped": 0,
    "conflict": 0,
    "failed": 1
  }
}
```

### Observable Result

- stdout contains exactly the execution document above;
- stderr may contain the permission diagnostic but is not parsed;
- the process exits non-zero;
- the Codex User Scope target remains installed;
- the Claude Code Workspace target is absent after compensation;
- the App maps `workspace.persistence_failed` to ARB copy and offers retry because `retryable` is true.

## Acceptance Criteria

1. The worked example produces one schema-versioned stdout document with one succeeded target, one failed target, and matching summary counts.
2. The failed Workspace group is compensated while the successful unrelated User Scope group remains committed.
3. `add`, `update`, and `manage` write complete results before returning non-zero for any failed target.
4. Failed targets use one nested error object; succeeded and skipped targets omit it.
5. A recognized JSON or NDJSON failure before a normal result uses a final `phase: "error"` document.
6. CLI and App contract tests prove that changing localized stderr text does not change failure classification.
7. The App renders recovery from `code`, `retryable`, and `details`, and treats unknown codes as generic failures rather than malformed protocol.
8. Tests at the CLI `Execute` and App `SkillsGateway` seams cover serialization, compensation, exit status, optional diagnostics, and unsupported schema versions.

## Implementation Seams

- CLI command root serializes recognized machine-mode failures once.
- CLI Hub adapter translates Hub transport and protocol failures into the initial stable code set.
- Installation, update, and management command adapters construct nested target errors and apply one failure-exit rule.
- CLI process entry preserves stdout and exits with the classified status.
- App process adapter parses stdout into typed failures; App UI owns localization and recovery presentation.

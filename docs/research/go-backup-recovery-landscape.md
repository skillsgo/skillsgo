# Go Backup and Recovery Landscape for SkillsGo

Research date: 2026-08-01

## Research question

Does the Go ecosystem have a mature backup/recovery tool that SkillsGo can use
for the local, reversible adoption of an externally installed Skill? The
comparison focuses on filesystem snapshots, restoration safety, integrity
verification, symlink and Git working-tree behavior, and the cost of embedding
the tool in a desktop application.

## Executive conclusion

Yes. Go has mature backup programs, but none of the reviewed tools is a direct
replacement for SkillsGo's local adoption vault.

- **restic** is the strongest headless, encrypted, deduplicated snapshot
  program. It is a good candidate for a future opt-in, long-lived or off-device
  backup/export feature.
- **Kopia** is the strongest candidate when SkillsGo eventually wants a
  user-facing repository with policies, retention, browsing/mounting, and
  restore verification. It also supports atomic file writes and explicit
  overwrite controls, but those controls do not make a whole directory restore
  an application-level transaction.
- **rclone** is an excellent transfer and remote-storage adapter, not a
  snapshot backup engine. `sync` can delete destination data, and its normal
  symlink mode is not an exact topology-preserving backup.
- **Velero** is mature for Kubernetes resources and persistent volumes, not for
  arbitrary desktop directories.
- **go-git** and `git bundle` are useful for Git-aware inspection or Git-only
  transport. They are not a complete backup of a Skill's working tree because
  Git bundles intentionally omit uncommitted and local repository state.

For the current SkillsGo use case, keep the small, local recovery vault as a
SkillsGo-owned filesystem transaction. It must preserve the original path
topology and make the adoption projection reversible even when the Skill is a
Git checkout, a worktree, a symlink, or shared by several Agents. Add restic or
Kopia only as an optional long-term/export backend, behind a SkillsGo manifest
and a staging-restore/verification step.

## What “mature” means for this decision

Popularity alone is not enough. A useful backup backend for SkillsGo must answer
all of these questions:

1. Can it create multiple point-in-time snapshots and restore a selected one?
2. Does it verify stored data, and can the verification be scripted?
3. What happens if a restore is interrupted halfway through?
4. Does it preserve a directory, a regular file, a symlink, and a Git
   worktree as different object types?
5. Can the caller refuse to overwrite a path that a user changed after
   adoption?
6. Can it be used without turning a one-click local undo into a repository,
   password, cache, and retention-management project?

The last two questions are specific to SkillsGo. General backup tools optimize
for disaster recovery; adoption recovery optimizes for a short-lived,
user-confirmed undo of one filesystem transition.

## Comparison

| Tool | Primary model | Strong capabilities | Restore and verification model | Fit for local Skill adoption |
| --- | --- | --- | --- | --- |
| [restic](https://github.com/restic/restic) | Encrypted, deduplicated repository of filesystem snapshots | Cross-platform CLI, local/SFTP/HTTP/S3 and other backends, snapshots, encryption, deduplication, JSON-oriented scripting | `restore`, selective include/exclude, dry-run, `check` and `check --read-data`; preserves symlinks, hard links, and extended attributes with documented platform caveats | **Good future export backend; not the default local vault**. It has the right data model, but its in-place restore can be partially applied if interrupted and its repository/password lifecycle is heavier than a one-step undo |
| [Kopia](https://github.com/kopia/kopia) | Encrypted, deduplicated snapshot repository with policies | CLI and GUI, local/network/cloud repositories, retention policies, mount/browse, incremental snapshots, error correction, automatic maintenance | `snapshot restore` supports no-overwrite flags, symlink controls, dry-run-like selection, and `--write-files-atomically`; `snapshot verify` can download/decrypt/decompress all files for a test-restore-level check | **Best future user-facing backup backend** if SkillsGo adds durable backup history. Still needs SkillsGo's own target-occupancy guard, manifest, and staging restore |
| [rclone](https://github.com/rclone/rclone) | Copy/sync and remote-storage abstraction | Many object/cloud backends, checksums, `copy`, `sync`, `check`, encrypted `crypt`, advanced `bisync` | `copy` does not delete destination; `sync` makes destination match source and can delete; `check` compares size/hash or downloads both sides; `bisync` has safety checks but is explicitly advanced | **Not suitable as the adoption vault**. It has no immutable snapshot identity, and default symlink handling does not preserve a native symlink object |
| [Velero](https://github.com/vmware-tanzu/velero) | Kubernetes cluster/resource and persistent-volume backup | Cluster migration/DR, object storage, volume snapshots, Kubernetes controllers, Kopia-backed file-system backup | Restore is driven by Kubernetes resources and controllers; file-system backup is documented as beta and reads live mounted volumes rather than a point-in-time filesystem snapshot | **Not applicable** to desktop Skills. It adds a Kubernetes control plane and does not model an arbitrary local path transition |
| [go-git](https://github.com/go-git/go-git) + [Git bundle](https://git-scm.com/docs/git-bundle) | Git object/repository operations and Git-native transfer | Pure-Go Git API, repository inspection, refs/objects, clone/fetch; bundles can move full reachable Git history offline | A bundle can recreate refs and commits, but the official Git documentation says it omits the index, working tree, stash, per-repository config, hooks, and other local state | **Useful adjunct for Git detection/metadata, not a generic backup**. An adoption backup must still capture the complete working tree and `.git` state as filesystem objects |

## Tool findings

### restic

The official introduction describes the basic lifecycle as `init`, `backup`,
`snapshots`, `restore`, and periodic `check`; `check --read-data` reads all
repository data instead of checking only metadata ([introduction](https://restic.readthedocs.io/en/stable/010_introduction.html)).
The backup documentation confirms that each run creates a snapshot and that
content-defined chunking and deduplication reduce subsequent storage
([backing up](https://restic.readthedocs.io/en/stable/040_backup.html)). The
project's design document describes repository encryption, authenticated data,
and content-addressed blobs ([design](https://github.com/restic/restic/blob/master/doc/design.rst)).

Its restore behavior is unusually relevant to SkillsGo:

- It can restore a whole snapshot or selected paths and offers `--dry-run`.
- The official restore guide says symbolic links are restored as links, and
  documents preservation of hard links and extended attributes with platform
  caveats.
- In-place restore overwrites existing files by default and supports overwrite
  modes. Most importantly, the guide warns that an interrupted in-place restore
  can leave files partially restored and recommends creating a current backup
  before restoring another snapshot.

Those are good primitives for a general backup product, but the warning is a
hard boundary for adoption recovery: SkillsGo must not let a generic restore
command partially replace a user-visible Skill target. A safer integration
would restore into a new staging directory, verify it, and only then perform a
SkillsGo-controlled same-filesystem swap.

The scripting guide exposes machine-readable JSON for many commands and exit
errors ([scripting](https://restic.readthedocs.io/en/latest/075_scripting.html)).
That makes restic usable as a pinned external process if SkillsGo does not want
to import implementation packages. The repository itself is a complete CLI
program rather than a narrowly scoped “restore this one path” API, so an
embedded integration should pin a version and test upgrades.

### Kopia

Kopia's official feature page describes encrypted snapshots, compression,
deduplication, error correction, policies, local/network/cloud repositories,
mounting, selective restore, verification, and automatic maintenance
([features](https://kopia.io/docs/features/)). The repository can be local or
remote and is always encrypted with a user-controlled password
([repositories](https://kopia.io/docs/repositories/)).

The restore command exposes several controls that are useful to an adoption
workflow ([snapshot restore](https://kopia.io/docs/reference/command-line/common/snapshot-restore/)):

- `--no-overwrite-files`, `--no-overwrite-directories`, and
  `--no-overwrite-symlinks` can refuse classes of existing targets.
- `--skip-existing` and `--delete-extra` make the overwrite/delete policy
  explicit.
- `--write-files-atomically` prevents a file from being left partially written
  when a write is interrupted.

Kopia's consistency guide distinguishes structural verification from a full
  test restore. `snapshot verify --verify-files-percent=100` downloads,
decrypts, and decompresses every selected file, which is stronger than merely
checking that index entries and blobs exist ([consistency](https://kopia.io/docs/advanced/consistency/)).
That verification idea is worth borrowing even if SkillsGo keeps its local
vault format.

The important limitation is scope: atomic file writes and no-overwrite flags do
not constitute a transaction over the entire Skill directory, its parent
symlink, the Agent projection, and the durable recovery manifest. SkillsGo
would still need to own the preflight identity check and the final rename/swap.

### rclone

rclone's official README defines it as a program to sync files and directories
to and from cloud providers ([README](https://github.com/rclone/rclone)). The
command semantics explain why it should not be used as the adoption backup
engine:

- [`copy`](https://rclone.org/commands/rclone_copy/) skips identical files and
  never deletes destination files.
- [`sync`](https://rclone.org/commands/rclone_sync/) makes the destination match
  the source and can delete destination data; the docs explicitly recommend a
  dry run or interactive mode because data loss is possible.
- [`check`](https://rclone.org/commands/rclone_check/) compares sizes and hashes
  without changing either side, or can download both sides for a stronger
  comparison. This is useful as an external post-copy check, not as a snapshot
  identity.
- [`bisync`](https://rclone.org/bisync/) maintains two-way state and has access
  checks, recovery, locks, dry runs, and a maximum-delete guard, but the docs
  label it an advanced command and warn that misuse can cause data loss.

Symlinks are another mismatch. rclone's normal local sync does not transfer or
delete symlinks unless `--links` is supplied; with `--links`, it translates
symlinks to regular files with a `.rclonelink` extension rather than preserving
the native link object ([sync options](https://rclone.org/commands/rclone_sync/)).
Its `crypt` backend provides authenticated encrypted data and `cryptcheck`, but
that is remote transport encryption, not a local, reversible filesystem
transaction ([crypt](https://rclone.org/crypt/)).

### Velero

Velero is mature in a different domain. Its official overview defines it as a
backup/restore tool for Kubernetes cluster resources and persistent volumes,
with a server running in the cluster and a local CLI
([overview](https://velero.io/docs/main/)). Its File System Backup (FSB) docs
state that FSB is beta, uses Kopia for data movement, and reads a live mounted
filesystem rather than capturing all data at one point in time
([FSB](https://velero.io/docs/main/file-system-backup/)). The same page lists
Kubernetes-specific constraints such as unsupported `hostPath` volumes and
pod/node-agent orchestration.

It should not be introduced into SkillsGo merely because it is written in Go or
uses Kopia internally. Its resource graph, controllers, and object-storage
repository are designed for cluster disaster recovery, not a desktop user
confirming “undo adoption.”

### Git-native options

[go-git](https://github.com/go-git/go-git) is a useful pure-Go Git library with
high- and low-level APIs, but its current documentation warns that v6 APIs are
subject to change until v6 is officially released
([go-git documentation](https://go-git.github.io/docs/)). It is appropriate for
reading Git metadata, checking refs, or avoiding a dependency on the `git`
executable; it is not a general filesystem backup engine.

The official [`git bundle`](https://git-scm.com/docs/git-bundle) documentation
is explicit: `git bundle create ... --all` backs up refs and commits reachable
from those refs, but does **not** include the index, working tree, stash,
per-repository configuration, hooks, or other local state. A Git-backed Skill
can have untracked files, ignored files, a `.git` file for a worktree, or local
configuration that must survive adoption. Therefore a bundle can be an
additional Git history artifact, never the sole adoption backup.

## Recommendation for SkillsGo

### 1. Keep the local recovery vault as a SkillsGo-owned primitive

The existing adoption flow is a short-lived undo operation, not a disaster
recovery product. The default path should remain:

1. Inventory with `Lstat`-style semantics: distinguish regular file, directory,
   symlink, Git worktree `.git` file, dangling link, and loop; resolve shared
   physical roots without following links accidentally.
2. Capture the external installation by a same-filesystem rename into a
   per-adoption vault. Do not copy-and-delete when a rename can preserve the
   original bytes, mode, link text, and `.git` topology.
3. Write a versioned manifest atomically only after the capture is durable. The
   manifest should include the original lexical path, physical source identity,
   backup path, expected managed projection, source/package identity, created
   time, expiry, and a topology/content receipt.
4. Materialize the SkillsGo-managed projection only after the vault capture is
   complete. If materialization fails, restore the capture before reporting
   failure.
5. Restore only when the target is still the exact managed projection created
   by SkillsGo and the original path is still available. If a user has placed a
   directory, file, or symlink there, stop with a conflict and leave both the
   user data and backup untouched.
6. After restore, perform a recursive postcondition check and retain the
   recovery receipt until the user-visible operation is complete.

This approach avoids adding a password prompt, repository cache, retention
policy, network provider, and external binary to a one-click local operation.
It also makes the safety rule clear: a local vault protects against an
incorrect adoption operation, not disk failure or loss of the entire machine.

### 2. Use restic or Kopia only for an explicit long-term/export feature

If users later ask SkillsGo to retain historical Skill versions, copy backups to
another disk, or export to cloud storage, add a separate feature rather than
silently turning every adoption into a repository snapshot.

- Choose **restic** for a headless, scriptable, encrypted repository with broad
  backend support and a small operational surface.
- Choose **Kopia** for a user-facing repository with policies, browsing/mounting,
  GUI support, and stronger built-in verification/maintenance controls.
- Use either through a pinned binary or a deliberately pinned Go dependency;
  do not expose their repository format as the SkillsGo package contract.
- Keep a SkillsGo sidecar manifest that maps each backup snapshot to the exact
  original path, Agent projections, package/source identity, and expected
  topology. A repository snapshot alone does not know whether a path was a
  SkillsGo-managed symlink or a user's own symlink.
- Restore into a fresh staging directory, verify the sidecar receipt and the
  tool's own repository check, then atomically swap only after the target
  occupancy check passes. Never call a generic “restore in place” directly on a
  managed Skill path.

### 3. Integrity is layered, not “just MD5”

MD5 is not an adequate identity or safety decision. It can be useful for a
fast, non-adversarial transfer check, but SkillsGo should use a layered receipt:

| Layer | What to compare | Why |
| --- | --- | --- |
| Entry type | `Lstat` type for every entry: directory, regular file, symlink, and special/unsupported entry | Prevents restoring a directory as a file or following a link into an unrelated tree |
| Symlink representation | The exact `readlink` target string, including relative vs absolute form | Two links can resolve to the same directory today but behave differently after a move |
| Regular-file content | Size plus SHA-256 (or BLAKE3 if a vetted dependency is accepted); on final restore, optionally stream-compare bytes for critical files | Detects accidental corruption; the digest is a receipt, not proof against a malicious editor who can change both data and manifest |
| Directory topology | Deterministic, sorted manifest of relative path, type, mode, and child receipt | Detects missing, extra, or retyped entries without relying on directory mtimes |
| Metadata | Mode, executable bit, mtime, ownership/xattrs/ACLs only where the platform contract promises to preserve them | Avoids claiming a stronger restore guarantee than the filesystem adapter provides |
| Git state | Preserve the complete `.git` entry as a filesystem tree/file; additionally record `HEAD`, refs, and `git status --porcelain=v2 --untracked-files=all` when Git is available | Git history alone omits working-tree and local state |
| Operation identity | Manifest schema, source/backup lexical paths, expected managed link target, package identity, and expiry | Prevents a valid old backup from being restored onto the wrong Skill or wrong target |

The postcondition should compare the restored tree against the pre-adoption
receipt, not just compare one archive hash. For a local, non-adversarial vault,
SHA-256 plus type/link/metadata checks is sufficient for accidental corruption;
for a hostile backup location, a plain hash in the same mutable manifest is not
an authenticity mechanism and would require a separately protected key or
signature.

## Suggested future backend seam

If a durable backup feature is added, keep the product contract independent of
restic/Kopia/rclone repository formats:

```text
Capture(source, manifest metadata) -> immutable receipt
Verify(receipt)                     -> verified / diagnostic result
StageRestore(receipt, empty path)   -> staged tree
CommitRestore(staged tree, target)  -> atomic, guarded replacement
Expire(receipt)                     -> explicit retention operation
```

The first implementation can be the current filesystem vault. A later restic
or Kopia adapter can implement the same seam without changing adoption
semantics. `rclone` can remain a transport adapter for an exported repository,
and `go-git` can remain a Git metadata/inspection adapter.

## Sources

All sources below are first-party project documentation or source repositories,
checked on 2026-08-01:

- [restic repository](https://github.com/restic/restic), [introduction](https://restic.readthedocs.io/en/stable/010_introduction.html), [backing up](https://restic.readthedocs.io/en/stable/040_backup.html), [restoring](https://restic.readthedocs.io/en/stable/050_restore.html), [scripting](https://restic.readthedocs.io/en/latest/075_scripting.html), and [design](https://github.com/restic/restic/blob/master/doc/design.rst).
- [Kopia repository](https://github.com/kopia/kopia), [features](https://kopia.io/docs/features/), [repositories](https://kopia.io/docs/repositories/), [snapshot restore](https://kopia.io/docs/reference/command-line/common/snapshot-restore/), and [consistency verification](https://kopia.io/docs/advanced/consistency/).
- [rclone repository](https://github.com/rclone/rclone), [copy](https://rclone.org/commands/rclone_copy/), [sync](https://rclone.org/commands/rclone_sync/), [check](https://rclone.org/commands/rclone_check/), [bisync](https://rclone.org/bisync/), and [crypt](https://rclone.org/crypt/).
- [Velero repository](https://github.com/vmware-tanzu/velero), [overview](https://velero.io/docs/main/), and [File System Backup](https://velero.io/docs/main/file-system-backup/).
- [go-git repository](https://github.com/go-git/go-git), [go-git documentation](https://go-git.github.io/docs/), [git-bundle](https://git-scm.com/docs/git-bundle), and [git-archive](https://git-scm.com/docs/git-archive).

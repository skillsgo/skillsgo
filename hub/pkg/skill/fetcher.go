/*
 * [INPUT]: Depends on the skill package imports and contracts declared in this file.
 * [OUTPUT]: Defines source revision, complete Repository Artifact snapshots, and validated Repository member metadata.
 * [POS]: Serves as the source boundary between Repository publication orchestration and Git resolution.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"context"
	"io"
	"time"

	protocolmanifest "github.com/skillsgo/skillsgo/protocol/skillmanifest"
)

// Resolution is the immutable result of resolving a requested revision.
type Resolution struct {
	Requested  string
	Version    string
	Ref        string
	CommitSHA  string
	TreeSHA    string
	CommitTime time.Time
}

// RepositoryFetcher resolves and scans one immutable Repository snapshot,
// returning every installable Skill without repeating source synchronization.
type RepositoryFetcher interface {
	DiscoverRepository(ctx context.Context, repositoryID, revision string) (*RepositorySnapshot, error)
}

type RepositorySnapshot struct {
	RepositoryID string
	Version      string
	Ref          string
	CommitSHA    string
	TreeSHA      string
	CommitTime   time.Time
	Archive      io.ReadCloser
	ArchiveMD5   []byte
	Sum          string
	ArchiveSize  int64
	Members      []RepositoryMember
}

type RepositoryMember struct {
	SkillID  string
	Name     string
	Path     string
	TreeSHA  string
	Manifest protocolmanifest.Manifest
}

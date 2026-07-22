/*
 * [INPUT]: Depends on the skill package imports and contracts declared in this file.
 * [OUTPUT]: Defines source revision, complete Repository Artifact snapshot, validated member metadata, and transitional legacy fetch contracts.
 * [POS]: Serves as the source boundary between Repository publication orchestration and Git resolution.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"context"
	"io"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	protocolmanifest "github.com/skillsgo/skillsgo/protocol/skillmanifest"
)

// Fetcher fetches a Skill from an upstream source.
type Fetcher interface {
	// Fetch downloads a Skill from an upstream and returns the corresponding
	// .info, .mod, and .zip files.
	Fetch(ctx context.Context, skillPath, revision string) (*storage.Version, error)
}

// Resolution is the immutable result of resolving a requested revision.
type Resolution struct {
	Requested  string
	Version    string
	Ref        string
	CommitSHA  string
	TreeSHA    string
	CommitTime time.Time
}

// ResolvedFetcher separates lightweight revision resolution from artifact
// download so callers can check storage before fetching Skill contents.
type ResolvedFetcher interface {
	Fetcher
	Resolve(ctx context.Context, skillPath, revision string) (*Resolution, error)
	FetchResolved(ctx context.Context, skillPath string, resolution *Resolution) (*storage.Version, error)
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
	Path     string
	TreeSHA  string
	Manifest protocolmanifest.Manifest
}

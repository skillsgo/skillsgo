/*
 * [INPUT]: Depends on contexts, immutable Repository revisions, validated Artifact entries and Skill manifests, plus visitor callbacks over leased Backfill sessions.
 * [OUTPUT]: Defines source revision, lightweight immutable resolution, complete validated Package Artifact trees, Repository member metadata, and explicit one-sync Backfill session contracts.
 * [POS]: Serves as the source boundary between Repository publication orchestration and Git resolution.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"context"
	"time"

	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
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
	Resolve(ctx context.Context, packagePath, revision string) (*Resolution, error)
	DiscoverRepository(ctx context.Context, packagePath, revision string) (*RepositorySnapshot, error)
	VisitRepositorySnapshots(ctx context.Context, packagePath string, revisions []string, visit func(string, *RepositorySnapshot, error) error) error
}

// RepositoryBackfillSession owns the source Repository lease from the one
// synchronization that discovers Versions through all selected snapshot visits.
type RepositoryBackfillSession interface {
	PackagePath() string
	Versions() []RepositoryTag
	VisitSnapshots(ctx context.Context, revisions []string, visit func(string, *RepositorySnapshot, error) error) error
	Close()
}

type RepositoryBackfillPreparer interface {
	PrepareRepositoryBackfill(ctx context.Context, packagePath string) (RepositoryBackfillSession, error)
}

type RepositorySnapshot struct {
	PackagePath string
	Version     string
	Ref         string
	CommitSHA   string
	TreeSHA     string
	CommitTime  time.Time
	Entries     []protocolartifact.Entry
	Sum         string
	Members     []RepositoryMember
}

type RepositoryMember struct {
	Name     string
	Path     string
	TreeSHA  string
	Content  []byte
	Manifest protocolmanifest.Manifest
}

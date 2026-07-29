/*
 * [INPUT]: Depends on the skill package imports and contracts declared in this file.
 * [OUTPUT]: Defines source revision, complete validated Package Artifact trees, and Repository member metadata.
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
	DiscoverRepository(ctx context.Context, packagePath, revision string) (*RepositorySnapshot, error)
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

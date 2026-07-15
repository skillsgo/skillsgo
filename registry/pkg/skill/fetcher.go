package skill

import (
	"context"
	"time"

	"github.com/skillsgo/skillsgo/registry/pkg/storage"
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

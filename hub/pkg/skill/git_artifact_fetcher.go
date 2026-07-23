/*
 * [INPUT]: Depends on filesystem-backed collision-safe repository caches, bounded cache lifecycle policy, credential-free controlled non-interactive Git source resolution, and artifact packaging.
 * [OUTPUT]: Provides the public-only Git-backed Repository fetcher with a controlled credential-free Git environment and concurrency-safe repository leases.
 * [POS]: Serves as the Repository cache and transport foundation of the Hub source boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"context"
	"crypto/sha256"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/spf13/afero"
	"golang.org/x/sync/singleflight"
)

type gitFetcher struct {
	fs            afero.Fs
	cacheDir      string
	syncs         singleflight.Group
	cloneURL      func(RepositoryID) string
	runGitCommand func(context.Context, string, []string, []string) ([]byte, error)
	cacheTTL      time.Duration
	cacheMaxBytes int64
	now           func() time.Time
	cleanupEvery  time.Duration
	lastCleanup   time.Time
	cleanupMu     sync.Mutex
	lifecycleMu   sync.Mutex
	activeRepos   map[string]int
}

// FetcherOption configures the Git-backed Repository fetcher.
type FetcherOption func(*gitFetcher)

// WithRepositoryCachePolicy configures expiration and the aggregate on-disk
// repository cache quota. Non-positive values disable the corresponding rule.
func WithRepositoryCachePolicy(ttl time.Duration, maxBytes int64) FetcherOption {
	return func(fetcher *gitFetcher) {
		fetcher.cacheTTL = ttl
		fetcher.cacheMaxBytes = maxBytes
	}
}

// NewRepositoryFetcher creates a Repository fetcher backed by Git.
func NewRepositoryFetcher(cacheDir string, fs afero.Fs, options ...FetcherOption) (RepositoryFetcher, error) {
	if cacheDir == "" {
		var err error
		cacheDir, err = os.MkdirTemp("", "skillsgo-cache-")
		if err != nil {
			return nil, err
		}
	}
	if err := fs.MkdirAll(cacheDir, 0o700); err != nil {
		return nil, err
	}
	fetcher := &gitFetcher{
		fs:            fs,
		cacheDir:      cacheDir,
		cloneURL:      func(skillID RepositoryID) string { return skillID.RepositoryURL() },
		runGitCommand: runGitCommand,
		cacheTTL:      7 * 24 * time.Hour,
		cacheMaxBytes: 10 << 30,
		now:           time.Now,
		cleanupEvery:  5 * time.Minute,
		activeRepos:   map[string]int{},
	}
	for _, option := range options {
		option(fetcher)
	}
	return fetcher, nil
}

func (g *gitFetcher) repositoryDir(repository string) (string, error) {
	parsed, err := ParseRepositoryID(repository)
	if err != nil {
		return "", fmt.Errorf("invalid repository cache path %q: %w", repository, err)
	}
	repository = parsed.Repository

	root := filepath.Join(g.cacheDir, "repositories")
	host, _, _ := strings.Cut(repository, "/")
	digest := sha256.Sum256([]byte(repository))
	// A digest keeps provider-specific case-sensitive paths distinct even on
	// case-insensitive filesystems while the host prefix remains operable.
	dir := filepath.Join(root, host, fmt.Sprintf("%x", digest))
	relative, err := filepath.Rel(root, dir)
	if err != nil || relative == ".." || strings.HasPrefix(relative, ".."+string(filepath.Separator)) {
		return "", fmt.Errorf("repository cache path %q escapes cache root", repository)
	}
	return dir, nil
}

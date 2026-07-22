/*
 * [INPUT]: Depends on filesystem-backed collision-safe repository caches, bounded cache lifecycle policy, credential-free controlled non-interactive Git source resolution, and artifact packaging.
 * [OUTPUT]: Provides public-only Git-backed Skill fetching with a controlled credential-free Git environment and concurrency-safe repository leases.
 * [POS]: Serves as maintained source in the skill package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"context"
	"crypto/md5" //nolint:gosec
	"crypto/sha256"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"github.com/spf13/afero"
	"golang.org/x/sync/singleflight"
)

type gitFetcher struct {
	fs            afero.Fs
	cacheDir      string
	syncs         singleflight.Group
	cloneURL      func(SkillID) string
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

type artifactFiles struct {
	Path    string
	Version string
	Info    string
	Zip     string
}

// FetcherOption configures the Git-backed Skill fetcher.
type FetcherOption func(*gitFetcher)

// WithRepositoryCachePolicy configures expiration and the aggregate on-disk
// repository cache quota. Non-positive values disable the corresponding rule.
func WithRepositoryCachePolicy(ttl time.Duration, maxBytes int64) FetcherOption {
	return func(fetcher *gitFetcher) {
		fetcher.cacheTTL = ttl
		fetcher.cacheMaxBytes = maxBytes
	}
}

// NewFetcher creates a Skill fetcher backed by Git.
func NewFetcher(cacheDir string, fs afero.Fs, options ...FetcherOption) (Fetcher, error) {
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
		cloneURL:      func(skillID SkillID) string { return skillID.RepositoryURL() },
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

// Fetch resolves and downloads an immutable Skill version from Git.
func (g *gitFetcher) Fetch(ctx context.Context, skillPath, revision string) (*storage.Version, error) {
	return g.fetch(ctx, skillPath, revision, nil)
}

// FetchResolved downloads an artifact for an already resolved revision.
func (g *gitFetcher) FetchResolved(ctx context.Context, skillPath string, resolution *Resolution) (*storage.Version, error) {
	return g.fetch(ctx, skillPath, resolution.Requested, resolution)
}

func (g *gitFetcher) fetch(ctx context.Context, skillPath, revision string, resolution *Resolution) (*storage.Version, error) {
	const op errors.Op = "gitFetcher.Fetch"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	skillID, err := ParseSkillID(skillPath)
	if err != nil {
		return nil, errors.E(op, err, errors.KindNotFound)
	}
	release, err := g.acquireRepository(skillID.Repository)
	if err != nil {
		return nil, errors.E(op, err)
	}
	defer release()

	// Create an isolated workspace that is removed when the returned ZIP closes.
	workspace, err := afero.TempDir(g.fs, g.cacheDir, "artifacts-")
	if err != nil {
		return nil, errors.E(op, err)
	}
	artifactDir := filepath.Join(workspace, "artifacts", getRepoDirName(skillPath, revision))
	if err := g.fs.MkdirAll(artifactDir, os.ModeDir|os.ModePerm); err != nil {
		_ = clearFiles(g.fs, workspace)
		return nil, errors.E(op, err)
	}

	m, err := g.downloadWithGit(ctx, workspace, artifactDir, skillPath, revision, resolution)
	if err != nil {
		_ = clearFiles(g.fs, workspace)
		return nil, errors.E(op, err)
	}

	var storageVer storage.Version
	storageVer.Semver = m.Version
	info, err := afero.ReadFile(g.fs, m.Info)
	if err != nil {
		return nil, errors.E(op, err)
	}
	storageVer.Info = info

	zipMD5, err := func() ([]byte, error) {
		// Perform in a separate function to ensure file is closed
		zipForChecksum, err := g.fs.Open(m.Zip)
		if err != nil {
			return nil, errors.E(op, err)
		}
		defer zipForChecksum.Close()

		//nolint:gosec
		hash := md5.New()
		if _, err := io.Copy(hash, zipForChecksum); err != nil {
			return nil, errors.E(op, err)
		}

		return hash.Sum(nil), nil
	}()
	if err != nil {
		return nil, err
	}

	zip, err := g.fs.Open(m.Zip)
	if err != nil {
		return nil, errors.E(op, err)
	}
	// note: don't close zip here so that the caller can read directly from disk.
	//
	// if we close, then the caller will panic, and the alternative to make this work is
	// that we read into memory and return an io.ReadCloser that reads out of memory
	storageVer.Zip = &zipReadCloser{zip, g.fs, workspace}
	storageVer.ZipMD5 = zipMD5

	return &storageVer, nil
}

func (g *gitFetcher) repositoryDir(repository string) (string, error) {
	parsed, err := ParseSkillID(repository)
	if err != nil {
		return "", fmt.Errorf("invalid repository cache path %q: %w", repository, err)
	}
	if parsed.SkillPath != "." {
		return "", fmt.Errorf("invalid repository cache path %q: nested Skill ID", repository)
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

// getRepoDirName takes a raw repository URI and a version and creates a directory name that the
// repository contents can be put into.
func getRepoDirName(repoURI, version string) string {
	escapedURI := strings.ReplaceAll(repoURI, "/", "-")
	return fmt.Sprintf("%s-%s", escapedURI, version)
}

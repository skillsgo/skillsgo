package skill

import (
	"context"
	"crypto/md5" //nolint:gosec
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/skillsgo/skillsgo/registry/pkg/errors"
	"github.com/skillsgo/skillsgo/registry/pkg/observ"
	"github.com/skillsgo/skillsgo/registry/pkg/storage"
	"github.com/spf13/afero"
	"golang.org/x/sync/singleflight"
)

type gitFetcher struct {
	fs       afero.Fs
	cacheDir string
	syncs    singleflight.Group
	cloneURL func(SkillCoordinate) string
}

type artifactFiles struct {
	Path     string
	Version  string
	Info     string
	Manifest string
	Zip      string
}

// NewFetcher creates a Skill fetcher backed by Git.
func NewFetcher(cacheDir string, fs afero.Fs) (Fetcher, error) {
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
	return &gitFetcher{
		fs:       fs,
		cacheDir: cacheDir,
		cloneURL: func(coordinate SkillCoordinate) string { return coordinate.RepositoryURL() },
	}, nil
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

	storageVer.Manifest, err = afero.ReadFile(g.fs, m.Manifest)
	if err != nil {
		return nil, errors.E(op, err)
	}

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
	if err := validateCoordinatePath(repository); err != nil {
		return "", fmt.Errorf("invalid repository cache path %q: %w", repository, err)
	}

	root := filepath.Join(g.cacheDir, "repositories")
	// GitHub repository coordinates are case-insensitive. Lowercasing avoids
	// duplicate caches on case-sensitive filesystems and collisions on macOS.
	dir := filepath.Join(root, filepath.FromSlash(strings.ToLower(repository)))
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

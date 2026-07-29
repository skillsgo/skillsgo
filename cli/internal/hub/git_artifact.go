/*
 * [INPUT]: Depends on go-git v6, a static dumb-HTTP Git repository URL, one immutable tag, and canonical Protocol Artifact entries.
 * [OUTPUT]: Clones an exact parentless Artifact tag without invoking system Git and restores its tree as validated Package entries.
 * [POS]: Serves as the CLI transport adapter from CDN-hosted Git objects to the Package Store's transport-neutral entry model.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package hub

import (
	"context"
	"crypto/sha256"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"sync"
	"time"

	git "github.com/go-git/go-git/v6"
	gitconfig "github.com/go-git/go-git/v6/config"
	"github.com/go-git/go-git/v6/plumbing"
	"github.com/go-git/go-git/v6/plumbing/client"
	"github.com/go-git/go-git/v6/plumbing/filemode"
	"github.com/go-git/go-git/v6/plumbing/object"
	githttp "github.com/go-git/go-git/v6/plumbing/transport/http"
	"github.com/gofrs/flock"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
)

func fetchArtifactEntries(ctx context.Context, httpClient *http.Client, repositoryURL, version string, progress func(int64, int64)) ([]protocolartifact.Entry, error) {
	cacheRoot, err := os.UserCacheDir()
	if err != nil {
		cacheRoot = os.TempDir()
	}
	digest := sha256.Sum256([]byte(repositoryURL))
	repositoryPath := filepath.Join(cacheRoot, "skillsgo", "git-artifacts", fmt.Sprintf("%x.git", digest[:16]))
	if err := os.MkdirAll(filepath.Dir(repositoryPath), 0o755); err != nil {
		return nil, err
	}
	cacheLock := flock.New(repositoryPath + ".lock")
	locked, err := cacheLock.TryLockContext(ctx, 50*time.Millisecond)
	if err != nil {
		return nil, err
	}
	if !locked {
		return nil, ctx.Err()
	}
	defer func() { _ = cacheLock.Unlock() }()
	artifactClient := *httpClient
	counter := &countingRoundTripper{base: httpClient.Transport, progress: progress}
	artifactClient.Transport = counter
	transport := githttp.NewTransport(githttp.Options{Client: &artifactClient, ForceDumb: true})
	clientOptions := []client.Option(nil)
	if parsed, parseErr := http.NewRequest(http.MethodGet, repositoryURL, nil); parseErr == nil && (parsed.URL.Scheme == "http" || parsed.URL.Scheme == "https") {
		clientOptions = []client.Option{client.WithTransport(parsed.URL.Scheme, transport)}
	}
	repository, err := git.PlainOpen(repositoryPath)
	if err == nil {
		ref := plumbing.NewTagReferenceName(version)
		fetchErr := repository.FetchContext(ctx, &git.FetchOptions{RemoteName: "origin", Force: true, Tags: git.NoTags, RefSpecs: []gitconfig.RefSpec{gitconfig.RefSpec("+" + ref.String() + ":" + ref.String())}, ClientOptions: clientOptions})
		if fetchErr != nil && fetchErr != git.NoErrAlreadyUpToDate {
			return nil, fmt.Errorf("update Git Artifact %s: %w", version, fetchErr)
		}
	} else {
		repository, err = git.PlainCloneContext(ctx, repositoryPath, &git.CloneOptions{URL: repositoryURL, NoCheckout: true, SingleBranch: true, ReferenceName: plumbing.NewTagReferenceName(version), Tags: git.NoTags, ClientOptions: clientOptions})
		if err != nil {
			_ = os.RemoveAll(repositoryPath)
			return nil, fmt.Errorf("download Git Artifact %s: %w", version, err)
		}
	}
	entries, err := artifactEntries(repository, version)
	if err == nil && progress != nil {
		progress(counter.bytes, counter.bytes)
	}
	return entries, err
}

type countingRoundTripper struct {
	base     http.RoundTripper
	progress func(int64, int64)
	mu       sync.Mutex
	bytes    int64
}

func (transport *countingRoundTripper) RoundTrip(request *http.Request) (*http.Response, error) {
	base := transport.base
	if base == nil {
		base = http.DefaultTransport
	}
	response, err := base.RoundTrip(request)
	if err == nil && response.Body != nil {
		response.Body = &countingBody{ReadCloser: response.Body, transport: transport}
	}
	return response, err
}

type countingBody struct {
	io.ReadCloser
	transport *countingRoundTripper
}

func (body *countingBody) Read(buffer []byte) (int, error) {
	read, err := body.ReadCloser.Read(buffer)
	if read > 0 {
		body.transport.mu.Lock()
		body.transport.bytes += int64(read)
		current := body.transport.bytes
		body.transport.mu.Unlock()
		if body.transport.progress != nil {
			body.transport.progress(current, -1)
		}
	}
	return read, err
}

func artifactEntries(repository *git.Repository, version string) ([]protocolartifact.Entry, error) {
	reference, err := repository.Reference(plumbing.NewTagReferenceName(version), true)
	if err != nil {
		return nil, err
	}
	commit, err := repository.CommitObject(reference.Hash())
	if err != nil {
		return nil, err
	}
	if commit.NumParents() != 0 {
		return nil, fmt.Errorf("Artifact commit %s has parents", commit.Hash)
	}
	tree, err := commit.Tree()
	if err != nil {
		return nil, err
	}
	entries := make([]protocolartifact.Entry, 0)
	err = tree.Files().ForEach(func(file *object.File) error {
		contents, readErr := file.Contents()
		if readErr != nil {
			return readErr
		}
		mode := os.FileMode(0o644)
		if file.Mode == filemode.Executable {
			mode = 0o755
		}
		if file.Mode == filemode.Symlink {
			mode = os.ModeSymlink | 0o777
		}
		entries = append(entries, protocolartifact.Entry{Path: file.Name, Contents: []byte(contents), Mode: mode})
		return nil
	})
	if err != nil {
		return nil, err
	}
	sort.Slice(entries, func(i, j int) bool { return entries[i].Path < entries[j].Path })
	return protocolartifact.ValidateEntries(entries)
}

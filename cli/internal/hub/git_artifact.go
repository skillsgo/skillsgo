/*
 * [INPUT]: Depends on go-git v6, a static HTTP(S) or local-file Git repository URL, one immutable tag, and canonical Protocol Artifact entries.
 * [OUTPUT]: Synchronizes advertised dumb-HTTP Pack/index files and immutable refs into the disposable ~/.skillsgo/cache/packages repository cache, repairs corrupt repositories once, then restores the requested parentless tree as validated Package entries.
 * [POS]: Serves as the CLI transport adapter from CDN-hosted Git objects to the Package Provider's transport-neutral immutable entry model.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package hub

import (
	"bufio"
	"context"
	"crypto/sha256"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"

	git "github.com/go-git/go-git/v6"
	"github.com/go-git/go-git/v6/plumbing"
	"github.com/go-git/go-git/v6/plumbing/filemode"
	"github.com/go-git/go-git/v6/plumbing/object"
	"github.com/gofrs/flock"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
)

const maxArtifactObjectFileBytes = 200 << 20

var artifactPackLine = regexp.MustCompile(`^P (pack-[0-9a-f]{40,64}\.pack)$`)

func fetchArtifactEntries(ctx context.Context, httpClient *http.Client, repositoryURL, version string, progress func(int64, int64)) ([]protocolartifact.Entry, error) {
	parsedRepository, err := url.Parse(repositoryURL)
	if err != nil {
		return nil, err
	}
	if parsedRepository.Scheme == "file" {
		if parsedRepository.Host != "" && parsedRepository.Host != "localhost" {
			return nil, fmt.Errorf("unsupported Artifact file host %q", parsedRepository.Host)
		}
		repository, openErr := git.PlainOpen(parsedRepository.Path)
		if openErr != nil {
			return nil, fmt.Errorf("open local Git Artifact %s: %w", version, openErr)
		}
		entries, readErr := artifactEntries(repository, version)
		if readErr == nil && progress != nil {
			progress(0, 0)
		}
		return entries, readErr
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, fmt.Errorf("resolve SkillsGo cache home: %w", err)
	}
	digest := sha256.Sum256([]byte(repositoryURL))
	repositoryPath := filepath.Join(home, ".skillsgo", "cache", "packages", fmt.Sprintf("%x", digest[:16]))
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
	entries, err := restoreCachedArtifact(ctx, &artifactClient, repositoryURL, repositoryPath, version)
	if err != nil {
		// Existing Pack/index bytes are immutable and sync intentionally skips
		// them. If the disposable repository cannot be read, rebuild that exact
		// cache coordinate once rather than leaking corruption to every command.
		if removeErr := os.RemoveAll(repositoryPath); removeErr != nil {
			return nil, fmt.Errorf("discard corrupt Git Artifact cache: %w", removeErr)
		}
		entries, err = restoreCachedArtifact(ctx, &artifactClient, repositoryURL, repositoryPath, version)
	}
	if err == nil && progress != nil {
		progress(counter.bytes, counter.bytes)
	}
	return entries, err
}

func restoreCachedArtifact(ctx context.Context, client *http.Client, repositoryURL, repositoryPath, version string) ([]protocolartifact.Entry, error) {
	if _, openErr := git.PlainOpen(repositoryPath); openErr != nil {
		if _, initErr := git.PlainInit(repositoryPath, true); initErr != nil {
			return nil, fmt.Errorf("initialize Git Artifact cache: %w", initErr)
		}
	}
	if err := syncDumbRepository(ctx, client, repositoryURL, repositoryPath); err != nil {
		return nil, fmt.Errorf("download Git Artifact %s: %w", version, err)
	}
	repository, err := git.PlainOpen(repositoryPath)
	if err != nil {
		return nil, err
	}
	return artifactEntries(repository, version)
}

func syncDumbRepository(ctx context.Context, client *http.Client, repositoryURL, repositoryPath string) error {
	packIndex, err := getArtifactFile(ctx, client, strings.TrimRight(repositoryURL, "/")+"/objects/info/packs")
	if err != nil {
		return err
	}
	packDirectory := filepath.Join(repositoryPath, "objects", "pack")
	if err := os.MkdirAll(packDirectory, 0o755); err != nil {
		return err
	}
	for _, line := range strings.Split(strings.TrimSpace(string(packIndex)), "\n") {
		match := artifactPackLine.FindStringSubmatch(strings.TrimSpace(line))
		if len(match) != 2 {
			if strings.TrimSpace(line) == "" {
				continue
			}
			return fmt.Errorf("invalid Artifact Pack index line %q", line)
		}
		packName := match[1]
		for _, name := range []string{strings.TrimSuffix(packName, ".pack") + ".idx", packName} {
			target := filepath.Join(packDirectory, name)
			if _, statErr := os.Stat(target); statErr == nil {
				continue
			} else if !os.IsNotExist(statErr) {
				return statErr
			}
			contents, downloadErr := getArtifactFile(ctx, client, strings.TrimRight(repositoryURL, "/")+"/objects/pack/"+name)
			if downloadErr != nil {
				return downloadErr
			}
			if writeErr := writeArtifactFile(target, contents); writeErr != nil {
				return writeErr
			}
		}
	}
	refs, err := getArtifactFile(ctx, client, strings.TrimRight(repositoryURL, "/")+"/info/refs")
	if err != nil {
		return err
	}
	repository, err := git.PlainOpen(repositoryPath)
	if err != nil {
		return err
	}
	scanner := bufio.NewScanner(strings.NewReader(string(refs)))
	for scanner.Scan() {
		parts := strings.SplitN(scanner.Text(), "\t", 2)
		if len(parts) != 2 || !plumbing.ReferenceName(parts[1]).IsTag() && !plumbing.ReferenceName(parts[1]).IsBranch() {
			return fmt.Errorf("invalid Artifact ref line %q", scanner.Text())
		}
		if err := repository.Storer.SetReference(plumbing.NewHashReference(plumbing.ReferenceName(parts[1]), plumbing.NewHash(parts[0]))); err != nil {
			return err
		}
	}
	return scanner.Err()
}

func getArtifactFile(ctx context.Context, client *http.Client, location string) ([]byte, error) {
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, location, nil)
	if err != nil {
		return nil, err
	}
	response, err := client.Do(request)
	if err != nil {
		return nil, err
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("GET %s returned %s", location, response.Status)
	}
	return readArtifactFile(response.Body, location)
}

func readArtifactFile(reader io.Reader, location string) ([]byte, error) {
	contents, err := io.ReadAll(io.LimitReader(reader, maxArtifactObjectFileBytes+1))
	if err != nil {
		return nil, err
	}
	if len(contents) > maxArtifactObjectFileBytes {
		return nil, fmt.Errorf("Artifact object %s exceeds 200 MiB", location)
	}
	return contents, nil
}

func writeArtifactFile(target string, contents []byte) error {
	temporary, err := os.CreateTemp(filepath.Dir(target), ".artifact-*")
	if err != nil {
		return err
	}
	temporaryName := temporary.Name()
	defer os.Remove(temporaryName)
	if _, err := temporary.Write(contents); err != nil {
		_ = temporary.Close()
		return err
	}
	if err := temporary.Close(); err != nil {
		return err
	}
	return os.Rename(temporaryName, target)
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

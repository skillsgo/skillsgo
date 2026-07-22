/*
 * [INPUT]: Depends on canonical Repository cache paths, repository metadata timestamps, filesystem sizing, and process-local repository leases.
 * [OUTPUT]: Provides TTL- and quota-based least-recently-used cleanup without removing repositories used by in-flight source operations.
 * [POS]: Serves as the lifecycle manager for persistent Git mirrors in the Hub Skill source module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"encoding/json"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

type repositoryCacheEntry struct {
	dir       string
	updatedAt time.Time
	size      int64
}

func (g *gitFetcher) acquireRepository(repository string) (func(), error) {
	dir, err := g.repositoryDir(repository)
	if err != nil {
		return nil, err
	}
	g.lifecycleMu.Lock()
	g.activeRepos[dir]++
	g.lifecycleMu.Unlock()
	metadataPath := filepath.Join(dir, "metadata.json")
	if _, statErr := os.Stat(metadataPath); statErr == nil {
		now := g.now().UTC()
		_ = os.Chtimes(metadataPath, now, now)
	}
	return func() {
		g.lifecycleMu.Lock()
		g.activeRepos[dir]--
		if g.activeRepos[dir] == 0 {
			delete(g.activeRepos, dir)
		}
		g.lifecycleMu.Unlock()
	}, nil
}

func (g *gitFetcher) cleanupRepositoryCache() error {
	if g.cacheTTL <= 0 && g.cacheMaxBytes <= 0 {
		return nil
	}
	g.cleanupMu.Lock()
	defer g.cleanupMu.Unlock()

	root := filepath.Join(g.cacheDir, "repositories")
	entries, err := repositoryCacheEntries(root)
	if errors.Is(err, fs.ErrNotExist) {
		return nil
	}
	if err != nil {
		return err
	}
	sort.Slice(entries, func(i, j int) bool {
		if entries[i].updatedAt.Equal(entries[j].updatedAt) {
			return entries[i].dir < entries[j].dir
		}
		return entries[i].updatedAt.Before(entries[j].updatedAt)
	})

	var total int64
	for _, entry := range entries {
		total += entry.size
	}
	deadline := g.now().UTC().Add(-g.cacheTTL)
	for _, entry := range entries {
		expired := g.cacheTTL > 0 && entry.updatedAt.Before(deadline)
		overQuota := g.cacheMaxBytes > 0 && total > g.cacheMaxBytes
		if !expired && !overQuota {
			continue
		}
		g.lifecycleMu.Lock()
		if g.activeRepos[entry.dir] == 0 {
			if err := os.RemoveAll(entry.dir); err != nil {
				g.lifecycleMu.Unlock()
				return err
			}
			total -= entry.size
		}
		g.lifecycleMu.Unlock()
	}
	return nil
}

func (g *gitFetcher) maybeCleanupRepositoryCache() error {
	now := g.now().UTC()
	g.cleanupMu.Lock()
	if !g.lastCleanup.IsZero() && now.Sub(g.lastCleanup) < g.cleanupEvery {
		g.cleanupMu.Unlock()
		return nil
	}
	g.lastCleanup = now
	g.cleanupMu.Unlock()
	return g.cleanupRepositoryCache()
}

func repositoryCacheEntries(root string) ([]repositoryCacheEntry, error) {
	hosts, err := os.ReadDir(root)
	if err != nil {
		return nil, err
	}
	entries := make([]repositoryCacheEntry, 0)
	for _, host := range hosts {
		if !host.IsDir() {
			continue
		}
		digests, readErr := os.ReadDir(filepath.Join(root, host.Name()))
		if readErr != nil {
			return nil, readErr
		}
		for _, digest := range digests {
			if !digest.IsDir() || !isRepositoryCacheDigest(digest.Name()) {
				continue
			}
			dir := filepath.Join(root, host.Name(), digest.Name())
			entry, entryErr := inspectRepositoryCacheEntry(dir)
			if entryErr != nil {
				return nil, entryErr
			}
			entries = append(entries, entry)
		}
	}
	return entries, nil
}

func isRepositoryCacheDigest(name string) bool {
	if len(name) != 64 {
		return false
	}
	return strings.IndexFunc(name, func(r rune) bool {
		return (r < '0' || r > '9') && (r < 'a' || r > 'f')
	}) == -1
}

func inspectRepositoryCacheEntry(dir string) (repositoryCacheEntry, error) {
	info, err := os.Stat(dir)
	if err != nil {
		return repositoryCacheEntry{}, err
	}
	updatedAt := info.ModTime().UTC()
	metadataPath := filepath.Join(dir, "metadata.json")
	if data, readErr := os.ReadFile(metadataPath); readErr == nil {
		var metadata repositoryMetadata
		if json.Unmarshal(data, &metadata) == nil && !metadata.UpdatedAt.IsZero() {
			updatedAt = metadata.UpdatedAt.UTC()
		}
		if metadataInfo, statErr := os.Stat(metadataPath); statErr == nil && metadataInfo.ModTime().After(updatedAt) {
			updatedAt = metadataInfo.ModTime().UTC()
		}
	}
	var size int64
	err = filepath.WalkDir(dir, func(_ string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if !entry.Type().IsRegular() {
			return nil
		}
		fileInfo, infoErr := entry.Info()
		if infoErr != nil {
			return infoErr
		}
		size += fileInfo.Size()
		return nil
	})
	return repositoryCacheEntry{dir: dir, updatedAt: updatedAt, size: size}, err
}

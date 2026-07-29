/*
 * [INPUT]: Depends on go-git object storage, packfile encoding, and filesystem-backed bare Artifact repositories.
 * [OUTPUT]: Provides self-contained incremental Pack creation for selected new objects and full repository compaction.
 * [POS]: Serves as the Pack lifecycle boundary for append-only publication and periodic base-Pack replacement.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package gitartifact

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"

	git "github.com/go-git/go-git/v6"
	"github.com/go-git/go-git/v6/plumbing"
	"github.com/go-git/go-git/v6/plumbing/format/packfile"
	"github.com/go-git/go-git/v6/plumbing/storer"
)

const initialPackWindow uint = 5

// Pack describes one materialized standard Git Pack and its index.
type Pack struct {
	Hash        plumbing.Hash
	ObjectCount int
	PackBytes   int64
	IndexBytes  int64
}

func packNewObjects(repositoryPath string, repository *git.Repository, hashes []plumbing.Hash) (Pack, error) {
	hashes = uniqueSortedHashes(hashes)
	if len(hashes) == 0 {
		return Pack{}, nil
	}
	packWriter, ok := repository.Storer.(storer.PackfileWriter)
	if !ok {
		return Pack{}, fmt.Errorf("Artifact repository storage cannot write Pack files")
	}
	looseObjects, ok := repository.Storer.(storer.LooseObjectStorer)
	if !ok {
		return Pack{}, fmt.Errorf("Artifact repository storage cannot remove packed loose objects")
	}
	config, err := repository.Config()
	if err != nil {
		return Pack{}, fmt.Errorf("read Artifact repository config: %w", err)
	}
	packWindow, err := publicationPackWindow(repository, config.Pack.Window)
	if err != nil {
		return Pack{}, err
	}
	writer, err := packWriter.PackfileWriter()
	if err != nil {
		return Pack{}, fmt.Errorf("create incremental Artifact Pack: %w", err)
	}
	packHash, encodeErr := packfile.NewEncoder(writer, repository.Storer, false).Encode(hashes, packWindow)
	closeErr := writer.Close()
	if encodeErr != nil {
		return Pack{}, fmt.Errorf("encode incremental Artifact Pack: %w", encodeErr)
	}
	if closeErr != nil {
		return Pack{}, fmt.Errorf("close incremental Artifact Pack: %w", closeErr)
	}
	for _, hash := range hashes {
		if err := looseObjects.DeleteLooseObject(hash); err != nil {
			return Pack{}, fmt.Errorf("delete packed loose Artifact object %s: %w", hash, err)
		}
	}
	return inspectPack(repositoryPath, packHash, len(hashes))
}

func publicationPackWindow(repository *git.Repository, configured uint) (uint, error) {
	packedObjects, ok := repository.Storer.(storer.PackedObjectStorer)
	if !ok {
		return 0, fmt.Errorf("Artifact repository storage cannot list Pack files")
	}
	packs, err := packedObjects.ObjectPacks()
	if err != nil {
		return 0, fmt.Errorf("list Artifact Packs before publication: %w", err)
	}
	if len(packs) == 0 {
		return initialPackWindow, nil
	}
	return configured, nil
}

// Compact replaces all current Packs and loose objects with one base Pack.
func Compact(repositoryPath string) (Pack, error) {
	repository, err := git.PlainOpen(repositoryPath)
	if err != nil {
		return Pack{}, fmt.Errorf("open Artifact repository for compaction: %w", err)
	}
	if err := repository.RepackObjects(&git.RepackConfig{}); err != nil {
		return Pack{}, fmt.Errorf("compact Artifact repository: %w", err)
	}
	if err := writeDumbHTTPIndexes(repositoryPath, repository); err != nil {
		return Pack{}, err
	}
	packedObjects, ok := repository.Storer.(storer.PackedObjectStorer)
	if !ok {
		return Pack{}, fmt.Errorf("Artifact repository storage cannot list Pack files")
	}
	packs, err := packedObjects.ObjectPacks()
	if err != nil {
		return Pack{}, fmt.Errorf("list compacted Artifact Packs: %w", err)
	}
	if len(packs) != 1 {
		return Pack{}, fmt.Errorf("compacted Artifact repository has %d Packs, want 1", len(packs))
	}
	return inspectPack(repositoryPath, packs[0], 0)
}

func inspectPack(repositoryPath string, hash plumbing.Hash, objectCount int) (Pack, error) {
	base := filepath.Join(repositoryPath, "objects", "pack", "pack-"+hash.String())
	packInfo, err := os.Stat(base + ".pack")
	if err != nil {
		return Pack{}, fmt.Errorf("stat Artifact Pack %s: %w", hash, err)
	}
	indexInfo, err := os.Stat(base + ".idx")
	if err != nil {
		return Pack{}, fmt.Errorf("stat Artifact Pack index %s: %w", hash, err)
	}
	return Pack{Hash: hash, ObjectCount: objectCount, PackBytes: packInfo.Size(), IndexBytes: indexInfo.Size()}, nil
}

func uniqueSortedHashes(hashes []plumbing.Hash) []plumbing.Hash {
	unique := make(map[plumbing.Hash]struct{}, len(hashes))
	for _, hash := range hashes {
		unique[hash] = struct{}{}
	}
	result := make([]plumbing.Hash, 0, len(unique))
	for hash := range unique {
		result = append(result, hash)
	}
	sort.Slice(result, func(i, j int) bool { return result[i].String() < result[j].String() })
	return result
}

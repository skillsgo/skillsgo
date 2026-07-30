/*
 * [INPUT]: Depends on validated Package Artifact entries, canonical immutable versions, deterministic commit time, and incremental Pack lifecycle primitives.
 * [OUTPUT]: Authors parentless Artifact commits, immutable lightweight Version tags with a typed conflict sentinel, a standard movable main/HEAD discovery ref, append-only incremental Packs, and dumb-HTTP indexes.
 * [POS]: Serves as the standard Git encoding boundary between Hub Package publication and repository-file storage.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package gitartifact

import (
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	git "github.com/go-git/go-git/v6"
	"github.com/go-git/go-git/v6/plumbing"
	"github.com/go-git/go-git/v6/plumbing/filemode"
	"github.com/go-git/go-git/v6/plumbing/object"
	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	protocolversion "github.com/skillsgo/skillsgo/protocol/version"
)

const artifactIdentity = "SkillsGo Hub"
const artifactEmail = "hub@skillsgo.ai"

var ErrImmutableTagConflict = errors.New("immutable Artifact tag conflict")

type treeNode struct {
	files    map[string]protocolartifact.Entry
	children map[string]*treeNode
}

// Publish adds one immutable Version to a standard bare Artifact Repository.
func Publish(repositoryPath, packagePath, version string, commitTime time.Time, entries []protocolartifact.Entry) (plumbing.Hash, bool, error) {
	if packagePath == "" || !protocolversion.IsImmutable(version) || commitTime.IsZero() {
		return plumbing.ZeroHash, false, fmt.Errorf("invalid Package Artifact publication identity")
	}
	validated, err := protocolartifact.ValidateEntries(entries)
	if err != nil {
		return plumbing.ZeroHash, false, err
	}
	repository, err := openOrInit(repositoryPath)
	if err != nil {
		return plumbing.ZeroHash, false, err
	}
	newObjects := make([]plumbing.Hash, 0)
	treeHash, err := writeTree(repository, validated, &newObjects)
	if err != nil {
		return plumbing.ZeroHash, false, err
	}
	signature := object.Signature{Name: artifactIdentity, Email: artifactEmail, When: commitTime.UTC()}
	commit := &object.Commit{
		Author: signature, Committer: signature, TreeHash: treeHash,
		Message: fmt.Sprintf("Publish %s@%s\n", packagePath, version),
	}
	encoded := repository.Storer.NewEncodedObject()
	if err := commit.Encode(encoded); err != nil {
		return plumbing.ZeroHash, false, fmt.Errorf("encode Artifact commit: %w", err)
	}
	commitHash, err := storeIfMissing(repository, encoded, &newObjects)
	if err != nil {
		return plumbing.ZeroHash, false, fmt.Errorf("store Artifact commit: %w", err)
	}
	tagName := plumbing.NewTagReferenceName(version)
	if existing, referenceErr := repository.Reference(tagName, true); referenceErr == nil {
		if existing.Hash() != commitHash {
			return plumbing.ZeroHash, false, fmt.Errorf("%w for %s@%s", ErrImmutableTagConflict, packagePath, version)
		}
		return commitHash, false, nil
	} else if referenceErr != plumbing.ErrReferenceNotFound {
		return plumbing.ZeroHash, false, referenceErr
	}
	if err := repository.Storer.SetReference(plumbing.NewHashReference(tagName, commitHash)); err != nil {
		return plumbing.ZeroHash, false, fmt.Errorf("publish Artifact tag: %w", err)
	}
	main := plumbing.NewBranchReferenceName("main")
	if err := repository.Storer.SetReference(plumbing.NewHashReference(main, commitHash)); err != nil {
		return plumbing.ZeroHash, false, fmt.Errorf("publish Artifact main ref: %w", err)
	}
	if err := repository.Storer.SetReference(plumbing.NewSymbolicReference(plumbing.HEAD, main)); err != nil {
		return plumbing.ZeroHash, false, fmt.Errorf("publish Artifact HEAD: %w", err)
	}
	if _, err := packNewObjects(repositoryPath, repository, newObjects); err != nil {
		return plumbing.ZeroHash, false, err
	}
	if err := writeDumbHTTPIndexes(repositoryPath, repository); err != nil {
		return plumbing.ZeroHash, false, err
	}
	return commitHash, true, nil
}

func openOrInit(repositoryPath string) (*git.Repository, error) {
	repository, err := git.PlainOpen(repositoryPath)
	if err == nil {
		return repository, nil
	}
	if !os.IsNotExist(err) && err != git.ErrRepositoryNotExists {
		return nil, err
	}
	if err := os.MkdirAll(filepath.Dir(repositoryPath), 0o755); err != nil {
		return nil, err
	}
	repository, err = git.PlainInit(repositoryPath, true)
	if err != nil {
		return nil, fmt.Errorf("initialize Artifact repository: %w", err)
	}
	return repository, nil
}

func writeTree(repository *git.Repository, entries []protocolartifact.Entry, newObjects *[]plumbing.Hash) (plumbing.Hash, error) {
	root := &treeNode{files: map[string]protocolartifact.Entry{}, children: map[string]*treeNode{}}
	for _, entry := range entries {
		segments := strings.Split(entry.Path, "/")
		node := root
		for _, segment := range segments[:len(segments)-1] {
			child := node.children[segment]
			if child == nil {
				child = &treeNode{files: map[string]protocolartifact.Entry{}, children: map[string]*treeNode{}}
				node.children[segment] = child
			}
			node = child
		}
		node.files[segments[len(segments)-1]] = entry
	}
	return writeTreeNode(repository, root, newObjects)
}

func writeTreeNode(repository *git.Repository, node *treeNode, newObjects *[]plumbing.Hash) (plumbing.Hash, error) {
	entries := make([]object.TreeEntry, 0, len(node.files)+len(node.children))
	for name, file := range node.files {
		encoded := repository.Storer.NewEncodedObject()
		encoded.SetType(plumbing.BlobObject)
		writer, err := encoded.Writer()
		if err != nil {
			return plumbing.ZeroHash, err
		}
		if _, err := writer.Write(file.Contents); err != nil {
			_ = writer.Close()
			return plumbing.ZeroHash, err
		}
		if err := writer.Close(); err != nil {
			return plumbing.ZeroHash, err
		}
		hash, err := storeIfMissing(repository, encoded, newObjects)
		if err != nil {
			return plumbing.ZeroHash, err
		}
		mode := filemode.Regular
		if file.IsSymlink() {
			mode = filemode.Symlink
		} else if file.Mode.Perm()&0o111 != 0 {
			mode = filemode.Executable
		}
		entries = append(entries, object.TreeEntry{Name: name, Mode: mode, Hash: hash})
	}
	for name, child := range node.children {
		hash, err := writeTreeNode(repository, child, newObjects)
		if err != nil {
			return plumbing.ZeroHash, err
		}
		entries = append(entries, object.TreeEntry{Name: name, Mode: filemode.Dir, Hash: hash})
	}
	sort.Sort(object.TreeEntrySorter(entries))
	tree := &object.Tree{Entries: entries}
	encoded := repository.Storer.NewEncodedObject()
	if err := tree.Encode(encoded); err != nil {
		return plumbing.ZeroHash, fmt.Errorf("encode Artifact tree: %w", err)
	}
	hash, err := storeIfMissing(repository, encoded, newObjects)
	if err != nil {
		return plumbing.ZeroHash, fmt.Errorf("store Artifact tree: %w", err)
	}
	return hash, nil
}

func storeIfMissing(repository *git.Repository, encoded plumbing.EncodedObject, newObjects *[]plumbing.Hash) (plumbing.Hash, error) {
	hash := encoded.Hash()
	if err := repository.Storer.HasEncodedObject(hash); err == nil {
		return hash, nil
	} else if err != plumbing.ErrObjectNotFound {
		return plumbing.ZeroHash, err
	}
	storedHash, err := repository.Storer.SetEncodedObject(encoded)
	if err != nil {
		return plumbing.ZeroHash, err
	}
	*newObjects = append(*newObjects, storedHash)
	return storedHash, nil
}

func writeDumbHTTPIndexes(repositoryPath string, repository *git.Repository) error {
	refs, err := repository.References()
	if err != nil {
		return err
	}
	defer refs.Close()
	lines := make([]string, 0)
	err = refs.ForEach(func(reference *plumbing.Reference) error {
		if reference.Type() == plumbing.HashReference && (reference.Name().IsTag() || reference.Name().IsBranch()) {
			lines = append(lines, reference.Hash().String()+"\t"+reference.Name().String()+"\n")
		}
		return nil
	})
	if err != nil {
		return err
	}
	sort.Strings(lines)
	if err := os.MkdirAll(filepath.Join(repositoryPath, "info"), 0o755); err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(repositoryPath, "info", "refs"), []byte(strings.Join(lines, "")), 0o644); err != nil {
		return err
	}
	packMatches, err := filepath.Glob(filepath.Join(repositoryPath, "objects", "pack", "pack-*.pack"))
	if err != nil {
		return err
	}
	sort.Strings(packMatches)
	packLines := make([]string, 0, len(packMatches))
	for _, packFile := range packMatches {
		packLines = append(packLines, "P "+filepath.Base(packFile)+"\n")
	}
	infoDir := filepath.Join(repositoryPath, "objects", "info")
	if err := os.MkdirAll(infoDir, 0o755); err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(infoDir, "packs"), []byte(strings.Join(packLines, "")), 0o644)
}

// Entries reads one tagged Artifact commit back into canonical entries.
func Entries(repository *git.Repository, version string) ([]protocolartifact.Entry, error) {
	reference, err := repository.Tag(version)
	if err != nil {
		return nil, err
	}
	commit, err := repository.CommitObject(reference.Hash())
	if err != nil {
		return nil, err
	}
	if len(commit.ParentHashes) != 0 {
		return nil, fmt.Errorf("Artifact commit %s has parents", commit.Hash)
	}
	tree, err := commit.Tree()
	if err != nil {
		return nil, err
	}
	iterator := tree.Files()
	defer iterator.Close()
	entries := make([]protocolartifact.Entry, 0)
	err = iterator.ForEach(func(file *object.File) error {
		reader, err := file.Reader()
		if err != nil {
			return err
		}
		contents, err := io.ReadAll(io.LimitReader(reader, protocolartifact.MaxUncompressedBytes+1))
		closeErr := reader.Close()
		if err != nil {
			return err
		}
		if closeErr != nil {
			return closeErr
		}
		if len(contents) > protocolartifact.MaxUncompressedBytes {
			return fmt.Errorf("Artifact file %q exceeds limit", file.Name)
		}
		mode, err := file.Mode.ToOSFileMode()
		if err != nil {
			return err
		}
		entries = append(entries, protocolartifact.Entry{Path: file.Name, Contents: contents, Mode: mode})
		return nil
	})
	if err != nil {
		return nil, err
	}
	return protocolartifact.ValidateEntries(entries)
}

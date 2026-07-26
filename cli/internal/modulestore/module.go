/*
 * [INPUT]: Depends on a coordinate Scope Module Store directory, its locked Module identity/version/Sum, and the shared Module Artifact format.
 * [OUTPUT]: Verifies a Module Store, reconstructs its canonical Module ZIP including safe symlinks, and compares deterministic selected-member Projections without inferring publication membership from arbitrary SKILL.md files.
 * [POS]: Serves as the trusted local read boundary from authoritative Scope Module Store back into projection transactions.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package modulestore

import (
	"fmt"
	"os"
	"path/filepath"

	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
)

func ReadVerifiedModule(modulesRoot, modulePath, version, expectedSum string) ([]byte, error) {
	root := CoordinatePath(modulesRoot, modulePath, version)
	actualSum, err := protocolartifact.ModuleDirectorySum(root, modulePath, version)
	if err != nil {
		return nil, fmt.Errorf("verify Scope Module Store %s@%s: %w", modulePath, version, err)
	}
	if actualSum != expectedSum {
		return nil, fmt.Errorf("Scope Module Store Local Modification for %s@%s: %s != %s", modulePath, version, actualSum, expectedSum)
	}
	entries := make([]protocolartifact.Entry, 0)
	err = filepath.WalkDir(root, func(current string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if current == root || entry.IsDir() {
			return nil
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		if !info.Mode().IsRegular() && info.Mode()&os.ModeSymlink == 0 {
			return fmt.Errorf("Scope Module Store contains unsupported file %s", current)
		}
		relative, err := filepath.Rel(root, current)
		if err != nil {
			return err
		}
		relative = filepath.ToSlash(relative)
		if _, err := protocolartifact.PortablePathKey(relative); err != nil {
			return err
		}
		var contents []byte
		if info.Mode()&os.ModeSymlink != 0 {
			target, readErr := os.Readlink(current)
			if readErr != nil {
				return readErr
			}
			contents = []byte(filepath.ToSlash(target))
		} else {
			contents, err = os.ReadFile(current)
			if err != nil {
				return err
			}
		}
		entries = append(entries, protocolartifact.Entry{Path: relative, Contents: contents, Mode: info.Mode()})
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("read Scope Module Store %s@%s: %w", modulePath, version, err)
	}
	archive, err := protocolartifact.BuildModule(modulePath, version, entries)
	if err != nil {
		return nil, err
	}
	rebuiltSum, err := protocolartifact.ModuleSum(archive, modulePath, version)
	if err != nil || rebuiltSum != expectedSum {
		return nil, fmt.Errorf("rebuilt Scope Module Store Sum mismatch for %s@%s", modulePath, version)
	}
	return archive, nil
}

// VerifyProjection compares an existing Repository Projection with the exact
// projection derived from verified artifact bytes and immutable membership.
func VerifyProjection(root, modulePath, version string, archive []byte, members, selected []string) error {
	memberSet, err := validateMembers(members)
	if err != nil {
		return err
	}
	selectedSet, err := validateSelection(selected, memberSet)
	if err != nil {
		return err
	}
	target := CoordinatePath(root, modulePath, version)
	expected, err := materialize(archive, modulePath, version, target, func(path string) bool {
		member, isManifest := memberForManifest(path, memberSet)
		return !isManifest || (member != "" && selectedSet[member])
	})
	if err != nil {
		return err
	}
	defer os.RemoveAll(expected)
	expectedDigest, err := treeDigest(expected)
	if err != nil {
		return err
	}
	actualDigest, err := treeDigest(target)
	if err != nil {
		return err
	}
	if actualDigest != expectedDigest {
		return fmt.Errorf("Repository Projection Local Modification for %s@%s", modulePath, version)
	}
	return nil
}

/*
 * [INPUT]: Depends on a coordinate Scope Vendor directory, its locked Repository identity/version/Sum, and the shared Repository Artifact format.
 * [OUTPUT]: Verifies an ordinary-file Vendor, reconstructs its canonical Repository ZIP, and compares deterministic selected-member Projections without inferring publication membership from arbitrary SKILL.md files.
 * [POS]: Serves as the trusted local read boundary from authoritative Scope Vendor back into projection transactions.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package scopevendor

import (
	"fmt"
	"os"
	"path/filepath"

	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
)

func ReadVerifiedVendor(vendorRoot, repositoryID, version, expectedSum string) ([]byte, error) {
	root := CoordinatePath(vendorRoot, repositoryID, version)
	actualSum, err := protocolartifact.RepositoryDirectorySum(root, repositoryID, version)
	if err != nil {
		return nil, fmt.Errorf("verify Scope Vendor %s@%s: %w", repositoryID, version, err)
	}
	if actualSum != expectedSum {
		return nil, fmt.Errorf("Scope Vendor Local Modification for %s@%s: %s != %s", repositoryID, version, actualSum, expectedSum)
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
		if !info.Mode().IsRegular() {
			return fmt.Errorf("Scope Vendor contains unsupported file %s", current)
		}
		relative, err := filepath.Rel(root, current)
		if err != nil {
			return err
		}
		relative = filepath.ToSlash(relative)
		if _, err := protocolartifact.PortablePathKey(relative); err != nil {
			return err
		}
		contents, err := os.ReadFile(current)
		if err != nil {
			return err
		}
		entries = append(entries, protocolartifact.Entry{Path: relative, Contents: contents, Mode: info.Mode()})
		return nil
	})
	if err != nil {
		return nil, fmt.Errorf("read Scope Vendor %s@%s: %w", repositoryID, version, err)
	}
	archive, err := protocolartifact.BuildRepository(repositoryID, version, entries)
	if err != nil {
		return nil, err
	}
	rebuiltSum, err := protocolartifact.RepositorySum(archive, repositoryID, version)
	if err != nil || rebuiltSum != expectedSum {
		return nil, fmt.Errorf("rebuilt Scope Vendor Sum mismatch for %s@%s", repositoryID, version)
	}
	return archive, nil
}

// VerifyProjection compares an existing Repository Projection with the exact
// projection derived from verified artifact bytes and immutable membership.
func VerifyProjection(root, repositoryID, version string, archive []byte, members, selected []string) error {
	memberSet, err := validateMembers(members)
	if err != nil {
		return err
	}
	selectedSet, err := validateSelection(selected, memberSet)
	if err != nil {
		return err
	}
	target := CoordinatePath(root, repositoryID, version)
	expected, err := materialize(archive, repositoryID, version, target, func(path string) bool {
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
		return fmt.Errorf("Repository Projection Local Modification for %s@%s", repositoryID, version)
	}
	return nil
}

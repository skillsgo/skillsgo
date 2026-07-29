/*
 * [INPUT]: Depends on a coordinate Scope Package Tree directory, its locked Package identity/version/Sum, and the shared Package Artifact format.
 * [OUTPUT]: Verifies a derived Scope Package Tree, reconstructs canonical entries including safe symlinks, and verifies Agent member links plus deterministic projections.
 * [POS]: Serves as the trusted local read boundary from a lock-verified Scope Package Tree back into projection transactions.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package packagestore

import (
	"fmt"
	"os"
	"path/filepath"

	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
)

func ReadVerifiedPackage(packagesRoot, packagePath, version, expectedSum string) ([]protocolartifact.Entry, error) {
	root := CoordinatePath(packagesRoot, packagePath, version)
	actualSum, err := protocolartifact.PackageDirectorySum(root, packagePath, version)
	if err != nil {
		return nil, fmt.Errorf("verify Scope Package Store %s@%s: %w", packagePath, version, err)
	}
	if actualSum != expectedSum {
		return nil, fmt.Errorf("Scope Package Store Local Modification for %s@%s: %s != %s", packagePath, version, actualSum, expectedSum)
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
			return fmt.Errorf("Scope Package Store contains unsupported file %s", current)
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
		return nil, fmt.Errorf("read Scope Package Store %s@%s: %w", packagePath, version, err)
	}
	entries, err = protocolartifact.ValidateEntries(entries)
	if err != nil {
		return nil, err
	}
	rebuiltSum, err := protocolartifact.PackageEntriesSum(entries, packagePath, version)
	if err != nil || rebuiltSum != expectedSum {
		return nil, fmt.Errorf("rebuilt Scope Package Store Sum mismatch for %s@%s", packagePath, version)
	}
	return entries, nil
}

// VerifyProjection compares an existing Package Projection with the exact
// projection derived from verified artifact bytes and immutable membership.
func VerifyProjection(root, packagePath, version string, entries []protocolartifact.Entry, members, selected []string) error {
	memberSet, err := validateMembers(members)
	if err != nil {
		return err
	}
	selectedSet, err := validateSelection(selected, memberSet)
	if err != nil {
		return err
	}
	target := CoordinatePath(root, packagePath, version)
	expected, err := materialize(entries, target, func(path string) bool {
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
		return fmt.Errorf("Package Projection Local Modification for %s@%s", packagePath, version)
	}
	return nil
}

// VerifyProjectionDirectory compares a Projection with selected content from
// an already verified Scope Package Store without materializing a temporary
// copy. Callers must verify packageRoot against the Workspace Lock first.
func VerifyProjectionDirectory(packageRoot, projectionRoot string, members, selected []string) error {
	memberSet, err := validateMembers(members)
	if err != nil {
		return err
	}
	selectedSet, err := validateSelection(selected, memberSet)
	if err != nil {
		return err
	}
	expectedDigest, err := projectionDigestFromDirectory(packageRoot, func(path string) bool {
		member, isManifest := memberForManifest(path, memberSet)
		return !isManifest || (member != "" && selectedSet[member])
	})
	if err != nil {
		return err
	}
	actualDigest, err := treeDigest(projectionRoot)
	if err != nil {
		return err
	}
	if actualDigest != expectedDigest {
		return fmt.Errorf("Package Projection Local Modification")
	}
	return nil
}

// VerifySkillProjection verifies that one Agent-visible Skill entry is a
// direct symlink to its immutable member directory in the Scope Package Store.
func VerifySkillProjection(packageRoot, projectionPath, memberPath string) error {
	expected := memberStorePath(packageRoot, memberPath)
	matches, err := existingProjectionLinkMatches(projectionPath, expected)
	if err != nil {
		return err
	}
	if !matches {
		return fmt.Errorf("Skill Projection Local Modification")
	}
	return nil
}

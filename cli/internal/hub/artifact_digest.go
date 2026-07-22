/*
 * [INPUT]: Depends on immutable Skill ZIP bytes or extracted Store directories, canonical Skill IDs, resolved versions, and the shared h1 Sum contract.
 * [OUTPUT]: Provides CLI-facing Sum validation and verification over the shared artifact protocol implementation.
 * [POS]: Serves as the CLI integrity boundary binding assessed Info metadata to downloaded and locally cached artifact files.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package hub

import (
	"fmt"

	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
)

// VerifySum rejects artifact bytes that do not match assessed Info.
func VerifySum(data []byte, skillID, version, expected string) error {
	actual, err := protocolartifact.Sum(data, skillID, version)
	if err != nil {
		return err
	}
	if actual != expected {
		return fmt.Errorf("Hub Sum mismatch for %s@%s: %s != %s", skillID, version, actual, expected)
	}
	return nil
}

// VerifyDirectorySum rejects a locally modified extracted Store artifact.
func VerifyDirectorySum(root, expected string) error {
	actual, err := protocolartifact.DirectorySum(root)
	if err != nil {
		return err
	}
	if actual != expected {
		return fmt.Errorf("Store Sum mismatch: %s != %s", actual, expected)
	}
	return nil
}

// DirectorySum applies the Hub Sum contract to an extracted
// artifact while rejecting symlinks, special files, and oversized content.
func DirectorySum(root string) (string, error) {
	return protocolartifact.DirectorySum(root)
}

// ValidSum reports whether value is a canonical h1 Sum.
func ValidSum(value string) bool { return protocolartifact.ValidSum(value) }

// Sum implements the Hub's normalized file-path/content framing.
func Sum(data []byte, skillID, version string) (string, error) {
	return protocolartifact.Sum(data, skillID, version)
}

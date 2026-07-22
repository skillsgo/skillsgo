/*
 * [INPUT]: Depends on immutable Skill ZIP bytes or extracted Store directories, canonical Skill IDs, resolved versions, and the Hub digest framing contract.
 * [OUTPUT]: Provides CLI-facing declared-digest verification over the shared artifact protocol implementation.
 * [POS]: Serves as the CLI integrity boundary binding assessed Info metadata to downloaded and locally cached artifact files.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package hub

import (
	"fmt"

	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
)

// VerifyContentDigest rejects artifact bytes that do not match assessed Info.
func VerifyContentDigest(data []byte, skillID, version, expected string) error {
	actual, err := protocolartifact.ContentDigest(data, skillID, version)
	if err != nil {
		return err
	}
	if actual != expected {
		return fmt.Errorf("Hub Content Digest mismatch for %s@%s: %s != %s", skillID, version, actual, expected)
	}
	return nil
}

// VerifyContentDirectory rejects a locally modified extracted Store artifact.
func VerifyContentDirectory(root, expected string) error {
	actual, err := protocolartifact.DirectoryContentDigest(root)
	if err != nil {
		return err
	}
	if actual != expected {
		return fmt.Errorf("Store Content Digest mismatch: %s != %s", actual, expected)
	}
	return nil
}

// ContentDirectoryDigest applies the Hub framing contract to an extracted
// artifact while rejecting symlinks, special files, and oversized content.
func ContentDirectoryDigest(root string) (string, error) {
	return protocolartifact.DirectoryContentDigest(root)
}

// ContentDigest implements the Hub's normalized file-path/content framing.
func ContentDigest(data []byte, skillID, version string) (string, error) {
	return protocolartifact.ContentDigest(data, skillID, version)
}

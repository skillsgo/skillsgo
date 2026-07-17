/*
 * [INPUT]: Depends on canonical Skill/version identity, immutable Info bytes, and a verified ZIP stream.
 * [OUTPUT]: Defines one Save operation for the maintained Info-plus-ZIP artifact pair.
 * [POS]: Serves as the write side of every Hub artifact storage backend.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package storage

import (
	"context"
	"io"
)

// Saver saves module metadata and its source to underlying storage.
type Saver interface {
	// Save saves the module metadata and its source to the storage.
	//
	// The caller MAY call zipMD5 with a nil value if the checksum is not available.
	// The storage implementation MAY use the zipMD5 to verify the integrity of the zip file.
	Save(ctx context.Context, module, version string, zip io.Reader, zipMD5, info []byte) error
}

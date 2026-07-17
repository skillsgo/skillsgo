/*
 * [INPUT]: Depends on immutable Info bytes and a deterministic Skill ZIP stream returned by source fetchers.
 * [OUTPUT]: Defines the in-process immutable Skill artifact value shared by fetch, stash, and storage boundaries.
 * [POS]: Serves as the Hub artifact transport value after independent Manifest contraction.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package storage

import "io"

// Version represents an immutable Skill version and its metadata and archive.
type Version struct {
	Zip    io.ReadCloser
	ZipMD5 []byte
	Info   []byte
	Semver string
}

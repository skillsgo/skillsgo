/*
 * [INPUT]: Depends on immutable Skill coordinates and canonical versions.
 * [OUTPUT]: Defines Info and ZIP reads plus the sized ZIP stream contract for every storage backend.
 * [POS]: Serves as the read side of the contracted Hub artifact storage boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package storage

import (
	"context"
	"io"
)

// Getter gets module metadata and its source from underlying storage.
type Getter interface {
	Info(ctx context.Context, module, vsn string) ([]byte, error)
	Zip(ctx context.Context, module, vsn string) (SizeReadCloser, error)
}

// SizeReadCloser extends io.ReadCloser
// with a Size() method that tells you the
// length of the io.ReadCloser if read in full.
type SizeReadCloser interface {
	io.ReadCloser
	Size() int64
}

// NewSizer is a helper wrapper to return an implementation
// of ReadCloserSizer.
func NewSizer(rc io.ReadCloser, size int64) SizeReadCloser {
	return &sizeReadCloser{rc, size}
}

type sizeReadCloser struct {
	io.ReadCloser

	size int64
}

func (zf *sizeReadCloser) Size() int64 {
	return zf.size
}

package storage

import "io"

// Version represents an immutable Skill version and its metadata and archive.
type Version struct {
	Manifest []byte
	Zip      io.ReadCloser
	ZipMD5   []byte
	Info     []byte
	Semver   string
}

/*
 * [INPUT]: Depends on MongoDB BSON identity plus canonical Skill/version, immutable Info metadata, and the reserved archive digest.
 * [OUTPUT]: Defines the Mongo-compatible metadata reservation paired with a GridFS ZIP.
 * [POS]: Serves as the backend-neutral persisted Skill metadata value without a Manifest artifact.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package storage

import (
	"go.mongodb.org/mongo-driver/v2/bson"
)

// Module represents a vgo module saved in a storage backend.
type Skill struct {
	// TODO(marwan-at-work): ID is a mongo-specific field, it should not be
	// in the generic storage.Skill struct.
	ID            bson.ObjectID `bson:"_id,omitempty"`
	Skill         string        `bson:"skill"`
	Version       string        `bson:"version"`
	Info          []byte        `bson:"info"`
	ArchiveSHA256 string        `bson:"archive_sha256"`
}

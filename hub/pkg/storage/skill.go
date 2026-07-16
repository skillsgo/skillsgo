package storage

import (
	"go.mongodb.org/mongo-driver/v2/bson"
)

// Module represents a vgo module saved in a storage backend.
type Skill struct {
	// TODO(marwan-at-work): ID is a mongo-specific field, it should not be
	// in the generic storage.Skill struct.
	ID       bson.ObjectID `bson:"_id,omitempty"`
	Skill    string        `bson:"skill"`
	Version  string        `bson:"version"`
	Manifest []byte        `bson:"manifest"`
	Info     []byte        `bson:"info"`
}

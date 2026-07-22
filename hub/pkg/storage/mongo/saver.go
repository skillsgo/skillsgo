/*
 * [INPUT]: Depends on MongoDB's unique metadata index, GridFS, and shared bounded immutable archive helpers.
 * [OUTPUT]: Provides reservation-first, idempotent PutIfAbsent persistence for Mongo-backed Info and ZIP artifacts.
 * [POS]: Serves as the Mongo immutable-write boundary, allowing identical retries to complete interrupted ZIP uploads.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package mongo

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

// Save stores a module in mongo storage.
func (s *SkillStore) Save(ctx context.Context, module, version string, zip io.Reader, zipMD5, info []byte) error {
	_, err := s.PutIfAbsent(ctx, module, version, zip, zipMD5, info)
	return err
}

// PutIfAbsent reserves the immutable coordinate in Mongo before uploading its GridFS archive.
func (s *SkillStore) PutIfAbsent(ctx context.Context, module, version string, zip io.Reader, zipMD5, info []byte) (bool, error) {
	const op errors.Op = "mongo.Save"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()

	archive, err := storage.ReadImmutableArchive(zip)
	if err != nil {
		return false, errors.E(op, err, errors.S(module), errors.V(version))
	}
	digest := sha256.Sum256(archive)
	digestText := hex.EncodeToString(digest[:])
	metadata := &storage.Skill{
		Skill:         module,
		Version:       version,
		Info:          info,
		ArchiveSHA256: digestText,
	}

	c := s.client.Database(s.db).Collection(s.coll)
	tctx, cancel := context.WithTimeout(ctx, s.timeout)
	defer cancel()
	_, err = c.InsertOne(tctx, metadata, options.InsertOne().SetBypassDocumentValidation(false))
	created := err == nil
	if err != nil && !mongo.IsDuplicateKeyError(err) {
		return false, errors.E(op, err, errors.S(module), errors.V(version))
	}
	if !created {
		existing, queryErr := query(ctx, s, module, version)
		if queryErr != nil {
			return false, errors.E(op, queryErr, errors.S(module), errors.V(version))
		}
		if !bytes.Equal(existing.Info, info) || existing.ArchiveSHA256 != digestText {
			return false, storage.ImmutableConflict(module, version)
		}
		matches, exists, matchErr := storage.ExistingZIPMatches(ctx, s, module, version, archive)
		if matchErr != nil {
			return false, errors.E(op, matchErr, errors.S(module), errors.V(version))
		}
		if exists {
			if !matches {
				return false, storage.ImmutableConflict(module, version)
			}
			return false, nil
		}
	}

	if err := s.uploadArchive(ctx, module, version, archive); err != nil {
		return false, err
	}
	return created, nil
}

func (s *SkillStore) uploadArchive(ctx context.Context, module, version string, archive []byte) error {
	const op errors.Op = "mongo.uploadArchive"
	zipName := s.gridFileName(module, version)
	db := s.client.Database(s.db)
	bucket := db.GridFSBucket(options.GridFSBucket())

	uStream, err := bucket.OpenUploadStream(ctx, zipName, options.GridFSUpload())
	if err != nil {
		return errors.E(op, err, errors.S(module), errors.V(version))
	}
	defer func() { _ = uStream.Close() }()

	numBytesWritten, err := io.Copy(uStream, bytes.NewReader(archive))
	if err != nil {
		return errors.E(op, err, errors.S(module), errors.V(version))
	}
	if numBytesWritten <= 0 {
		e := fmt.Errorf("copied %d bytes to Mongo GridFS", numBytesWritten)
		return errors.E(op, e, errors.S(module), errors.V(version))
	}

	return nil
}

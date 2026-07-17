/*
 * [INPUT]: Depends on the mongo package imports and contracts declared in this file.
 * [OUTPUT]: Provides the mongo package behavior implemented by saver.go.
 * [POS]: Serves as maintained source in the mongo package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package mongo

import (
	"context"
	"fmt"
	"io"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

// Save stores a module in mongo storage.
func (s *SkillStore) Save(ctx context.Context, module, version string, zip io.Reader, zipMD5, info []byte) error {
	const op errors.Op = "mongo.Save"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()

	exists, err := s.Exists(ctx, module, version)
	if err != nil {
		return errors.E(op, err, errors.S(module), errors.V(version))
	}
	if exists {
		return errors.E(op, "already exists", errors.S(module), errors.V(version), errors.KindAlreadyExists)
	}

	zipName := s.gridFileName(module, version)
	db := s.client.Database(s.db)
	bucket := db.GridFSBucket(options.GridFSBucket())

	uStream, err := bucket.OpenUploadStream(ctx, zipName, options.GridFSUpload())
	if err != nil {
		return errors.E(op, err, errors.S(module), errors.V(version))
	}
	defer func() { _ = uStream.Close() }()

	numBytesWritten, err := io.Copy(uStream, zip)
	if err != nil {
		return errors.E(op, err, errors.S(module), errors.V(version))
	}
	if numBytesWritten <= 0 {
		e := fmt.Errorf("copied %d bytes to Mongo GridFS", numBytesWritten)
		return errors.E(op, e, errors.S(module), errors.V(version))
	}

	m := &storage.Skill{
		Skill:   module,
		Version: version,
		Info:    info,
	}

	c := s.client.Database(s.db).Collection(s.coll)
	tctx, cancel := context.WithTimeout(ctx, s.timeout)
	defer cancel()

	_, err = c.InsertOne(tctx, m, options.InsertOne().SetBypassDocumentValidation(false))
	if err != nil {
		return errors.E(op, err, errors.S(module), errors.V(version))
	}

	return nil
}

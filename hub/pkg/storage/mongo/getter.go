/*
 * [INPUT]: Depends on the mongo package imports and contracts declared in this file.
 * [OUTPUT]: Provides the mongo package behavior implemented by getter.go.
 * [POS]: Serves as maintained source in the mongo package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package mongo

import (
	"context"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

// Info implements storage.Getter.
func (s *SkillStore) Info(ctx context.Context, module, vsn string) ([]byte, error) {
	const op errors.Op = "mongo.Info"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()

	result, err := query(ctx, s, module, vsn)
	if err != nil {
		return nil, errors.E(op, err)
	}

	return result.Info, nil
}

// Zip implements storage.Getter.
func (s *SkillStore) Zip(ctx context.Context, module, vsn string) (storage.SizeReadCloser, error) {
	const op errors.Op = "mongo.Zip"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()

	zipName := s.gridFileName(module, vsn)
	db := s.client.Database(s.db)
	bucket := db.GridFSBucket()

	dStream, err := bucket.OpenDownloadStreamByName(ctx, zipName, options.GridFSName())
	if err != nil {
		kind := errors.KindUnexpected
		if errors.IsErr(err, mongo.ErrFileNotFound) {
			kind = errors.KindNotFound
		}
		return nil, errors.E(op, err, kind, errors.S(module), errors.V(vsn))
	}
	res := s.client.Database(s.db).Collection("fs.files").FindOne(ctx, bson.M{
		"filename": zipName,
	})
	if res.Err() != nil {
		return nil, errors.E(op, res.Err())
	}
	var m bson.M
	err = res.Decode(&m)
	if err != nil {
		return nil, errors.E(op, err)
	}
	b, err := bson.Marshal(m)
	if err != nil {
		return nil, errors.E(op, err)
	}
	size, _ := bson.Raw(b).Lookup("length").Int64OK()
	return storage.NewSizer(dStream, size), nil
}

// Query connects to and queries storage module.
func query(ctx context.Context, s *SkillStore, module, vsn string) (*storage.Skill, error) {
	const op errors.Op = "mongo.query"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()

	c := s.client.Database(s.db).Collection(s.coll)

	result := &storage.Skill{}

	tctx, cancel := context.WithTimeout(ctx, s.timeout)
	defer cancel()

	queryResult := c.FindOne(tctx, bson.M{"skill": module, "version": vsn})
	if queryErr := queryResult.Err(); queryErr != nil {
		kind := errors.KindUnexpected
		if errors.IsErr(queryErr, mongo.ErrNoDocuments) {
			kind = errors.KindNotFound
		}
		return nil, errors.E(op, queryErr, kind, errors.S(module), errors.V(vsn))
	}

	if err := queryResult.Decode(result); err != nil {
		kind := errors.KindUnexpected
		if errors.IsErr(err, mongo.ErrNoDocuments) {
			kind = errors.KindNotFound
		}
		return nil, errors.E(op, err, kind, errors.S(module), errors.V(vsn))
	}

	return result, nil
}

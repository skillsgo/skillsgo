/*
 * [INPUT]: Depends on the mongo package imports and contracts declared in this file.
 * [OUTPUT]: Provides the mongo package behavior implemented by lister.go.
 * [POS]: Serves as maintained source in the mongo package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package mongo

import (
	"context"

	multierror "github.com/hashicorp/go-multierror"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

// List lists all versions of a module.
func (s *SkillStore) List(ctx context.Context, moduleName string) ([]string, error) {
	const op errors.Op = "mongo.List"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	c := s.client.Database(s.db).Collection(s.coll)
	projection := bson.M{"version": 1, "_id": 0}
	query := bson.M{"skill": moduleName}
	tctx, cancel := context.WithTimeout(ctx, s.timeout)
	defer cancel()

	cursor, err := c.Find(tctx, query, options.Find().SetProjection(projection))
	if err != nil {
		return nil, errors.E(op, err, errors.S(moduleName))
	}
	result := make([]storage.Skill, 0)
	var errs error
	for cursor.Next(ctx) {
		var module storage.Skill
		if err = cursor.Decode(&module); err != nil {
			kind := errors.KindUnexpected
			if errors.IsErr(err, mongo.ErrNoDocuments) {
				kind = errors.KindNotFound
			}
			errs = multierror.Append(errs, errors.E(op, err, kind))
		} else {
			result = append(result, module)
		}
	}

	versions := make([]string, len(result))
	for i, r := range result {
		versions[i] = r.Version
	}

	return versions, nil
}

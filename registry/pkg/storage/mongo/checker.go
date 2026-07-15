package mongo

import (
	"context"

	"github.com/skillsgo/skillsgo/registry/pkg/errors"
	"github.com/skillsgo/skillsgo/registry/pkg/observ"
	"go.mongodb.org/mongo-driver/v2/bson"
)

// Exists checks for a specific version of a module.
func (s *SkillStore) Exists(ctx context.Context, module, vsn string) (bool, error) {
	var op errors.Op = "mongo.Exists"
	ctx, span := observ.StartSpan(ctx, op.String())
	defer span.End()
	c := s.client.Database(s.db).Collection(s.coll)
	tctx, cancel := context.WithTimeout(ctx, s.timeout)
	defer cancel()

	count, err := c.CountDocuments(tctx, bson.M{"skill": module, "version": vsn})
	if err != nil {
		return false, errors.E(op, errors.S(module), errors.V(vsn), err)
	}
	return count > 0, nil
}

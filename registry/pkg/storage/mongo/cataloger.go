package mongo

import (
	"context"

	"github.com/hashicorp/go-multierror"
	"github.com/skillsgo/skillsgo/registry/pkg/errors"
	"github.com/skillsgo/skillsgo/registry/pkg/paths"
	"github.com/skillsgo/skillsgo/registry/pkg/storage"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

// Catalog implements the (./pkg/storage).Cataloger interface.
// It returns a list of modules and versions contained in the storage.
func (s *SkillStore) Catalog(ctx context.Context, token string, pageSize int) ([]paths.AllPathParams, string, error) {
	const op errors.Op = "mongo.Catalog"
	q := bson.M{}
	if token != "" {
		t, err := bson.ObjectIDFromHex(token)
		if err == nil {
			q = bson.M{"_id": bson.M{"$gt": t}}
		}
	}

	projection := bson.M{"skill": 1, "version": 1}
	sort := bson.M{"_id": 1}

	c := s.client.Database(s.db).Collection(s.coll)

	tctx, cancel := context.WithTimeout(ctx, s.timeout)
	defer cancel()
	modules := make([]storage.Skill, 0)
	findOptions := options.Find().SetProjection(projection).SetSort(sort).SetLimit(int64(pageSize))
	cursor, err := c.Find(tctx, q, findOptions)
	if err != nil {
		return nil, "", errors.E(op, err)
	}

	var errs error
	for cursor.Next(ctx) {
		var module storage.Skill
		if err := cursor.Decode(&module); err != nil {
			errs = multierror.Append(errs, err)
		} else {
			modules = append(modules, module)
		}
	}

	// If there are 0 results, return empty results without an error
	if len(modules) == 0 {
		return nil, "", nil
	}

	versions := make([]paths.AllPathParams, len(modules))
	for i := range modules {
		versions[i].Skill = modules[i].Skill
		versions[i].Version = modules[i].Version
	}

	next := modules[len(modules)-1].ID.Hex()
	if len(modules) < pageSize {
		return versions, "", nil
	}
	return versions, next, nil
}

/*
 * [INPUT]: Depends on the mongo package imports and contracts declared in this file.
 * [OUTPUT]: Provides the mongo package behavior implemented by checker.go.
 * [POS]: Serves as maintained source in the mongo package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package mongo

import (
	"context"

	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/observ"
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

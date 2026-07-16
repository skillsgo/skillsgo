/*
 * [INPUT]: Depends on the artifact package imports and contracts declared in this file.
 * [OUTPUT]: Specifies the artifact package behavior covered by delete_test.go.
 * [POS]: Serves as test coverage for the artifact package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package artifact

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/gobuffalo/envy"
	"github.com/stretchr/testify/suite"
)

type DeleteTests struct {
	suite.Suite
}

func TestDelete(t *testing.T) {
	suite.Run(t, new(DeleteTests))
}

func (d *DeleteTests) SetupTest() {
	envy.Set("SKILLSGO_HUB_TIMEOUT", "1")
}

func (d *DeleteTests) TearDownTest() {
	envy.Set("SKILLSGO_HUB_TIMEOUT", "300")
}

func (d *DeleteTests) TestDeleteTimeout() {
	r := d.Require()

	err := Delete(d.T().Context(), "mx", "1.1.1", delWithTimeout, time.Second)

	r.Error(err, "deleter returned at least one error")
	r.Contains(err.Error(), "deleting mx.1.1.1.info failed: context deadline exceeded")
	r.Contains(err.Error(), "deleting mx.1.1.1.zip failed: context deadline exceeded")
	r.Contains(err.Error(), "deleting mx.1.1.1.manifest failed: context deadline exceeded")
}

func (d *DeleteTests) TestDeleteError() {
	r := d.Require()

	err := Delete(d.T().Context(), "mx", "1.1.1", delWithErr, time.Second)

	r.Error(err, "deleter returned at least one error")
	r.Contains(err.Error(), "some err")
}

func delWithTimeout(ctx context.Context, path string) error {
	time.Sleep(2 * time.Second)
	return nil
}

func delWithErr(ctx context.Context, path string) error {
	return errors.New("some err")
}

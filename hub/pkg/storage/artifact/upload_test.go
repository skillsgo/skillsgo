/*
 * [INPUT]: Depends on the artifact package imports and contracts declared in this file.
 * [OUTPUT]: Specifies the artifact package behavior covered by upload_test.go.
 * [POS]: Serves as test coverage for the artifact package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package artifact

import (
	"bytes"
	"context"
	"errors"
	"io"
	"testing"
	"time"

	"github.com/gobuffalo/envy"
	"github.com/stretchr/testify/suite"
)

type UploadTests struct {
	suite.Suite
}

func TestUpload(t *testing.T) {
	suite.Run(t, new(UploadTests))
}

func (u *UploadTests) SetupTest() {
	envy.Set("SKILLSGO_HUB_TIMEOUT", "1")
}

func (u *UploadTests) TearDownTest() {
	envy.Set("SKILLSGO_HUB_TIMEOUT", "300")
}

func (u *UploadTests) TestUploadTimeout() {
	r := u.Require()
	rd := bytes.NewReader([]byte("123"))
	err := Upload(u.T().Context(), "mx", "1.1.1", rd, rd, uplWithTimeout, time.Second)
	r.Error(err, "deleter returned at least one error")
	r.Contains(err.Error(), "uploading mx.1.1.1.info failed: context deadline exceeded")
	r.Contains(err.Error(), "uploading mx.1.1.1.zip failed: context deadline exceeded")
}

func (u *UploadTests) TestUploadError() {
	r := u.Require()
	rd := bytes.NewReader([]byte("123"))
	err := Upload(u.T().Context(), "mx", "1.1.1", rd, rd, uplWithErr, time.Second)
	r.Error(err, "deleter returned at least one error")
	r.Contains(err.Error(), "some err")
}

func uplWithTimeout(ctx context.Context, path, contentType string, stream io.Reader) error {
	time.Sleep(2 * time.Second)
	return nil
}

func uplWithErr(ctx context.Context, path, contentType string, stream io.Reader) error {
	return errors.New("some err")
}

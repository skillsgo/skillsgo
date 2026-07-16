/*
 * [INPUT]: Depends on the download package imports and contracts declared in this file.
 * [OUTPUT]: Specifies the download package behavior covered by handler_test.go.
 * [POS]: Serves as test coverage for the download package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package download

import (
	"context"
	"net/http"
	"testing"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/download/mode"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
)

func TestRedirect(t *testing.T) {
	for _, url := range []string{"https://gomods.io", "https://internal.domain/repository/gonexus"} {
		r := fiber.New()
		RegisterHandlers(r, &HandlerOpts{
			Protocol: &mockProtocol{},
			Logger:   log.NoOpLogger(),
			DownloadFile: &mode.DownloadFile{
				Mode:        mode.Redirect,
				DownloadURL: url,
			},
		})
		for _, path := range [...]string{
			"/github.com/skillsgo/skillsgo/hub/@v/v0.4.0.info",
			"/github.com/skillsgo/skillsgo/hub/@v/v0.4.0.manifest",
			"/github.com/skillsgo/skillsgo/hub/@v/v0.4.0.zip",
		} {
			req, _ := http.NewRequest("GET", path, nil)
			response, err := r.Test(req)
			if err != nil {
				t.Fatal(err)
			}
			if response.StatusCode != http.StatusMovedPermanently {
				t.Fatalf("expected a redirect status (301) but got %v", response.StatusCode)
			}
			expectedRedirect := url + path
			givenRedirect := response.Header.Get("location")
			if expectedRedirect != givenRedirect {
				t.Fatalf("expected the handler to redirect to %q but got %q", expectedRedirect, givenRedirect)
			}
		}
	}
}

type mockProtocol struct {
	Protocol
}

func (mp *mockProtocol) Info(ctx context.Context, mod, ver string) ([]byte, error) {
	const op errors.Op = "mockProtocol.Info"
	return nil, errors.E(op, "not found", errors.KindRedirect)
}

func (mp *mockProtocol) Manifest(ctx context.Context, mod, ver string) ([]byte, error) {
	const op errors.Op = "mockProtocol.Manifest"
	return nil, errors.E(op, "not found", errors.KindRedirect)
}

func (mp *mockProtocol) Zip(ctx context.Context, mod, ver string) (storage.SizeReadCloser, error) {
	const op errors.Op = "mockProtocol.Zip"
	return nil, errors.E(op, "not found", errors.KindRedirect)
}

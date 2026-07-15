package download

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gorilla/mux"
	"github.com/skillsgo/skillsgo/registry/pkg/download/mode"
	"github.com/skillsgo/skillsgo/registry/pkg/errors"
	"github.com/skillsgo/skillsgo/registry/pkg/log"
	"github.com/skillsgo/skillsgo/registry/pkg/storage"
)

func TestRedirect(t *testing.T) {
	for _, url := range []string{"https://gomods.io", "https://internal.domain/repository/gonexus"} {
		r := mux.NewRouter()
		RegisterHandlers(r, &HandlerOpts{
			Protocol: &mockProtocol{},
			Logger:   log.NoOpLogger(),
			DownloadFile: &mode.DownloadFile{
				Mode:        mode.Redirect,
				DownloadURL: url,
			},
		})
		for _, path := range [...]string{
			"/github.com/skillsgo/skillsgo/registry/@v/v0.4.0.info",
			"/github.com/skillsgo/skillsgo/registry/@v/v0.4.0.manifest",
			"/github.com/skillsgo/skillsgo/registry/@v/v0.4.0.zip",
		} {
			req := httptest.NewRequest("GET", path, nil)
			w := httptest.NewRecorder()
			r.ServeHTTP(w, req)
			if w.Code != http.StatusMovedPermanently {
				t.Fatalf("expected a redirect status (301) but got %v", w.Code)
			}
			expectedRedirect := url + path
			givenRedirect := w.HeaderMap.Get("location")
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

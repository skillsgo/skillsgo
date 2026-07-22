/*
 * [INPUT]: Depends on Fiber routing, successful and redirected artifact protocols, canonical versions, and explicit movable Selectors.
 * [OUTPUT]: Specifies protocol namespacing, explicit Head/Release Selectors, exact-version enforcement, HTTP method boundaries, external immutable ZIP delivery, redirect behavior, and cache policy.
 * [POS]: Serves as the public artifact HTTP routing contract for the download package.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package download

import (
	"context"
	"io"
	"net/http"
	"strings"
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
			"/mod/github.com/skillsgo/skillsgo/hub/@v/v0.4.0.info",
			"/mod/github.com/skillsgo/skillsgo/hub/@v/v0.4.0.zip",
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

func TestArtifactProtocolIsNamespacedUnderMod(t *testing.T) {
	r := fiber.New()
	RegisterHandlers(r, &HandlerOpts{Protocol: &mockProtocol{}, Logger: log.NoOpLogger(), DownloadFile: &mode.DownloadFile{Mode: mode.Redirect, DownloadURL: "https://example.test"}})
	request, err := http.NewRequest(http.MethodGet, "/github.com/skillsgo/skillsgo/@v/v1.0.0.info", nil)
	if err != nil {
		t.Fatal(err)
	}
	response, err := r.Test(request)
	if err != nil {
		t.Fatal(err)
	}
	if response.StatusCode != http.StatusNotFound {
		t.Fatalf("legacy root protocol route returned %d, want 404", response.StatusCode)
	}
}

func TestExactResourceRoutesRejectMovableOrRawRevisionQueries(t *testing.T) {
	r := fiber.New()
	RegisterHandlers(r, &HandlerOpts{
		Protocol: &successfulProtocol{},
		Logger:   log.NoOpLogger(),
		DownloadFile: &mode.DownloadFile{
			Mode:        mode.Sync,
			DownloadURL: "https://files.skillsgo.ai",
		},
	})
	for _, requestCase := range []struct {
		method string
		path   string
	}{
		{http.MethodGet, "/mod/github.com/skillsgo/skillsgo/@v/main.info"},
		{http.MethodGet, "/mod/github.com/skillsgo/skillsgo/@v/main.zip"},
		{http.MethodHead, "/mod/github.com/skillsgo/skillsgo/@v/main.zip"},
		{http.MethodGet, "/mod/github.com/skillsgo/skillsgo/@v/abcdef123456.info"},
	} {
		request, err := http.NewRequest(requestCase.method, requestCase.path, nil)
		if err != nil {
			t.Fatal(err)
		}
		response, err := r.Test(request)
		if err != nil {
			t.Fatal(err)
		}
		if response.StatusCode != http.StatusBadRequest {
			t.Fatalf("%s %s returned %d, want 400", requestCase.method, requestCase.path, response.StatusCode)
		}
	}
}

func TestCanonicalVersionInfoIsPubliclyImmutable(t *testing.T) {
	r := fiber.New()
	RegisterHandlers(r, &HandlerOpts{Protocol: &successfulProtocol{}, Logger: log.NoOpLogger(), DownloadFile: &mode.DownloadFile{Mode: mode.Sync}})
	for _, path := range []string{
		"/mod/github.com/skillsgo/skillsgo/@v/v1.2.3.info",
		"/mod/github.com/skillsgo/skillsgo/@v/v1.2.4-0.20260720120000-abcdef123456.info",
	} {
		request, err := http.NewRequest(http.MethodGet, path, nil)
		if err != nil {
			t.Fatal(err)
		}
		response, err := r.Test(request)
		if err != nil {
			t.Fatal(err)
		}
		if got := response.Header.Get("Cache-Control"); got != immutableVersionCacheControl {
			t.Fatalf("%s Cache-Control = %q, want %q", path, got, immutableVersionCacheControl)
		}
		etag := response.Header.Get("ETag")
		if etag == "" {
			t.Fatalf("%s did not return an immutable ETag", path)
		}
		conditional, _ := http.NewRequest(http.MethodGet, path, nil)
		conditional.Header.Set("If-None-Match", etag)
		notModified, err := r.Test(conditional)
		if err != nil {
			t.Fatal(err)
		}
		if notModified.StatusCode != http.StatusNotModified || notModified.Header.Get("ETag") != etag {
			t.Fatalf("%s conditional response status=%d etag=%q", path, notModified.StatusCode, notModified.Header.Get("ETag"))
		}
	}
}

func TestCanonicalVersionZipSupportsConditionalGetAndHead(t *testing.T) {
	r := fiber.New()
	RegisterHandlers(r, &HandlerOpts{Protocol: &successfulProtocol{}, Logger: log.NoOpLogger(), DownloadFile: &mode.DownloadFile{Mode: mode.Sync}})
	path := "/mod/github.com/skillsgo/skillsgo/@v/v1.2.3.zip"
	request, _ := http.NewRequest(http.MethodHead, path, nil)
	response, err := r.Test(request)
	if err != nil {
		t.Fatal(err)
	}
	etag := response.Header.Get("ETag")
	if response.StatusCode != http.StatusOK || etag == "" {
		t.Fatalf("HEAD status=%d etag=%q", response.StatusCode, etag)
	}
	conditional, _ := http.NewRequest(http.MethodGet, path, nil)
	conditional.Header.Set("If-None-Match", etag)
	notModified, err := r.Test(conditional)
	if err != nil {
		t.Fatal(err)
	}
	if notModified.StatusCode != http.StatusNotModified || notModified.Header.Get("ETag") != etag {
		t.Fatalf("conditional ZIP status=%d etag=%q", notModified.StatusCode, notModified.Header.Get("ETag"))
	}
}

func TestExplicitSelectorsAndMethodContracts(t *testing.T) {
	r := fiber.New()
	RegisterHandlers(r, &HandlerOpts{Protocol: &successfulProtocol{}, Logger: log.NoOpLogger(), DownloadFile: &mode.DownloadFile{Mode: mode.Sync}})
	for _, selector := range []string{"head", "release"} {
		request, _ := http.NewRequest(http.MethodGet, "/mod/github.com/skillsgo/skillsgo/@"+selector, nil)
		response, err := r.Test(request)
		if err != nil {
			t.Fatal(err)
		}
		if response.StatusCode != http.StatusOK || response.Header.Get("Cache-Control") != movableVersionCacheControl {
			t.Fatalf("@%s returned status=%d cache=%q", selector, response.StatusCode, response.Header.Get("Cache-Control"))
		}
	}
	legacy, _ := http.NewRequest(http.MethodGet, "/mod/github.com/skillsgo/skillsgo/@latest", nil)
	legacyResponse, err := r.Test(legacy)
	if err != nil {
		t.Fatal(err)
	}
	if legacyResponse.StatusCode != http.StatusNotFound {
		t.Fatalf("legacy @latest returned %d", legacyResponse.StatusCode)
	}
	for _, item := range []struct {
		path  string
		allow string
	}{
		{"/mod/github.com/skillsgo/skillsgo/@v/list", http.MethodGet},
		{"/mod/github.com/skillsgo/skillsgo/@head", http.MethodGet},
		{"/mod/github.com/skillsgo/skillsgo/@v/v1.2.3.info", http.MethodGet},
		{"/mod/github.com/skillsgo/skillsgo/@v/v1.2.3.zip", http.MethodGet + ", " + http.MethodHead},
	} {
		request, _ := http.NewRequest(http.MethodPost, item.path, nil)
		response, err := r.Test(request)
		if err != nil {
			t.Fatal(err)
		}
		if response.StatusCode != http.StatusMethodNotAllowed || response.Header.Get("Allow") != item.allow {
			t.Fatalf("POST %s returned status=%d Allow=%q", item.path, response.StatusCode, response.Header.Get("Allow"))
		}
	}
}

func TestCanonicalVersionZipRedirectsToArtifactOrigin(t *testing.T) {
	r := fiber.New()
	RegisterHandlers(r, &HandlerOpts{
		Protocol: &successfulProtocol{},
		Logger:   log.NoOpLogger(),
		DownloadFile: &mode.DownloadFile{
			Mode:        mode.Sync,
			DownloadURL: "https://files.skillsgo.ai",
		},
	})

	for _, method := range []string{http.MethodGet, http.MethodHead} {
		request, err := http.NewRequest(method, "/mod/github.com/skillsgo/skillsgo/-/skills/example/@v/v1.2.3.zip", nil)
		if err != nil {
			t.Fatal(err)
		}
		response, err := r.Test(request)
		if err != nil {
			t.Fatal(err)
		}
		if response.StatusCode != http.StatusMovedPermanently {
			t.Fatalf("%s returned %d, want 301", method, response.StatusCode)
		}
		const expected = "https://files.skillsgo.ai/github.com/skillsgo/skillsgo/-/skills/example/@v/v1.2.3.zip"
		if got := response.Header.Get("Location"); got != expected {
			t.Fatalf("%s Location = %q, want %q", method, got, expected)
		}
	}
}

type mockProtocol struct {
	Protocol
}

type successfulProtocol struct {
	Protocol
}

func (p *successfulProtocol) Info(context.Context, string, string) ([]byte, error) {
	return []byte(`{"Version":"v1.0.0","Time":"2026-07-22T00:00:00Z"}`), nil
}

func (p *successfulProtocol) List(context.Context, string) ([]string, error) {
	return []string{"v1.0.0", "v2.0.0-rc.1"}, nil
}

func (p *successfulProtocol) Zip(context.Context, string, string) (storage.SizeReadCloser, error) {
	const archive = "zip"
	return storage.NewSizer(io.NopCloser(strings.NewReader(archive)), int64(len(archive))), nil
}

func (mp *mockProtocol) Info(ctx context.Context, mod, ver string) ([]byte, error) {
	const op errors.Op = "mockProtocol.Info"
	return nil, errors.E(op, "not found", errors.KindRedirect)
}

func (mp *mockProtocol) Zip(ctx context.Context, mod, ver string) (storage.SizeReadCloser, error) {
	const op errors.Op = "mockProtocol.Zip"
	return nil, errors.E(op, "not found", errors.KindRedirect)
}

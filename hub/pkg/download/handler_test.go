/*
 * [INPUT]: Depends on Fiber routing, successful and redirected artifact protocols, canonical versions, and explicit movable revisions.
 * [OUTPUT]: Specifies public Package Version metadata resolution, immutable ZIP enforcement, removal of legacy Proxy paths, HTTP method boundaries, external delivery, redirect behavior, and conditional cache policy.
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
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/storage"
)

func TestArtifactProtocolIsServedUnderV1API(t *testing.T) {
	r := fiber.New()
	RegisterHandlers(r, &HandlerOpts{Protocol: &successfulProtocol{}, Logger: log.NoOpLogger(), ArtifactOrigin: "https://example.test"})
	request, err := http.NewRequest(http.MethodGet, "/api/v1/github.com/skillsgo/skillsgo/versions/v1.0.0", nil)
	if err != nil {
		t.Fatal(err)
	}
	response, err := r.Test(request)
	if err != nil {
		t.Fatal(err)
	}
	if response.StatusCode != http.StatusOK {
		t.Fatalf("v1 Package distribution route returned %d, want 200", response.StatusCode)
	}
}

func TestPackageVersionsAreServedAsJSON(t *testing.T) {
	r := fiber.New()
	RegisterHandlers(r, &HandlerOpts{Protocol: &successfulProtocol{}, Logger: log.NoOpLogger()})
	request, err := http.NewRequest(http.MethodGet, "/api/v1/github.com/skillsgo/skillsgo/versions", nil)
	if err != nil {
		t.Fatal(err)
	}
	response, err := r.Test(request)
	if err != nil {
		t.Fatal(err)
	}
	body, err := io.ReadAll(response.Body)
	if err != nil {
		t.Fatal(err)
	}
	if response.StatusCode != http.StatusOK || response.Header.Get("Content-Type") != "application/json; charset=utf-8" || string(body) != `{"versions":["v1.0.0","v2.0.0-rc.1"]}` {
		t.Fatalf("versions response status=%d content-type=%q body=%s", response.StatusCode, response.Header.Get("Content-Type"), body)
	}
}

func TestRemovedModNamespaceIsNotInterpretedAsPackagePath(t *testing.T) {
	r := fiber.New()
	RegisterHandlers(r, &HandlerOpts{Protocol: &successfulProtocol{}, Logger: log.NoOpLogger()})
	request, err := http.NewRequest(http.MethodGet, "/mod/github.com/skillsgo/skillsgo/versions/v1.0.0", nil)
	if err != nil {
		t.Fatal(err)
	}
	response, err := r.Test(request)
	if err != nil {
		t.Fatal(err)
	}
	if response.StatusCode != http.StatusNotFound {
		t.Fatalf("removed /mod route returned %d, want 404", response.StatusCode)
	}
}

func TestLegacyProxyVersionPathsAreRemoved(t *testing.T) {
	r := fiber.New()
	RegisterHandlers(r, &HandlerOpts{Protocol: &successfulProtocol{}, Logger: log.NoOpLogger()})
	for _, legacyPath := range []string{
		"/api/v1/github.com/skillsgo/skillsgo/@v/list",
		"/api/v1/github.com/skillsgo/skillsgo/@v/v1.0.0.info",
		"/api/v1/github.com/skillsgo/skillsgo/@v/v1.0.0.zip",
	} {
		request, err := http.NewRequest(http.MethodGet, legacyPath, nil)
		if err != nil {
			t.Fatal(err)
		}
		response, err := r.Test(request)
		if err != nil {
			t.Fatal(err)
		}
		if response.StatusCode != http.StatusNotFound {
			t.Fatalf("legacy path %s returned %d, want 404", legacyPath, response.StatusCode)
		}
	}
}

func TestMetadataAcceptsMovableRevisionsWhileZipRejectsThem(t *testing.T) {
	r := fiber.New()
	RegisterHandlers(r, &HandlerOpts{
		Protocol:       &successfulProtocol{},
		Logger:         log.NoOpLogger(),
		ArtifactOrigin: "https://files.skillsgo.ai",
	})
	for _, path := range []string{
		"/api/v1/github.com/skillsgo/skillsgo/versions/main",
		"/api/v1/github.com/skillsgo/skillsgo/versions/latest",
		"/api/v1/github.com/skillsgo/skillsgo/versions/abcdef123456",
		"/api/v1/github.com/skillsgo/skillsgo/versions/feature%2Fdeep",
	} {
		requestCase := struct{ method, path string }{http.MethodGet, path}
		request, err := http.NewRequest(requestCase.method, requestCase.path, nil)
		if err != nil {
			t.Fatal(err)
		}
		response, err := r.Test(request)
		if err != nil {
			t.Fatal(err)
		}
		if response.StatusCode != http.StatusOK || response.Header.Get("Cache-Control") != movableVersionCacheControl {
			t.Fatalf("%s %s returned %d cache=%q, want 200 no-store", requestCase.method, requestCase.path, response.StatusCode, response.Header.Get("Cache-Control"))
		}
	}
	request, _ := http.NewRequest(http.MethodGet, "/api/v1/github.com/skillsgo/skillsgo/versions/main.zip", nil)
	response, err := r.Test(request)
	if err != nil {
		t.Fatal(err)
	}
	if response.StatusCode != http.StatusBadRequest {
		t.Fatalf("movable ZIP returned %d, want 400", response.StatusCode)
	}
}

func TestCanonicalVersionInfoIsPubliclyImmutable(t *testing.T) {
	r := fiber.New()
	RegisterHandlers(r, &HandlerOpts{Protocol: &successfulProtocol{}, Logger: log.NoOpLogger()})
	for _, path := range []string{
		"/api/v1/github.com/skillsgo/skillsgo/versions/v1.2.3",
		"/api/v1/github.com/skillsgo/skillsgo/versions/v1.2.4-0.20260720120000-abcdef123456",
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

func TestCanonicalVersionZipSupportsConditionalGet(t *testing.T) {
	r := fiber.New()
	RegisterHandlers(r, &HandlerOpts{Protocol: &successfulProtocol{}, Logger: log.NoOpLogger()})
	path := "/api/v1/github.com/skillsgo/skillsgo/versions/v1.2.3.zip"
	request, _ := http.NewRequest(http.MethodGet, path, nil)
	response, err := r.Test(request)
	if err != nil {
		t.Fatal(err)
	}
	etag := response.Header.Get("ETag")
	if response.StatusCode != http.StatusOK || etag == "" {
		t.Fatalf("GET status=%d etag=%q", response.StatusCode, etag)
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

func TestProxyRejectsMovableSelectorsAndEnforcesExactRouteMethods(t *testing.T) {
	r := fiber.New()
	RegisterHandlers(r, &HandlerOpts{Protocol: &successfulProtocol{}, Logger: log.NoOpLogger()})
	for _, selector := range []string{"head", "release", "latest"} {
		request, _ := http.NewRequest(http.MethodGet, "/api/v1/github.com/skillsgo/skillsgo/@"+selector, nil)
		response, err := r.Test(request)
		if err != nil {
			t.Fatal(err)
		}
		if response.StatusCode != http.StatusNotFound {
			t.Fatalf("removed Proxy selector @%s returned status=%d", selector, response.StatusCode)
		}
	}
	for _, item := range []struct {
		path  string
		allow string
	}{
		{"/api/v1/github.com/skillsgo/skillsgo/versions", http.MethodGet},
		{"/api/v1/github.com/skillsgo/skillsgo/versions/v1.2.3", http.MethodGet},
		{"/api/v1/github.com/skillsgo/skillsgo/versions/v1.2.3.zip", http.MethodGet},
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

func TestCanonicalVersionZipRejectsHead(t *testing.T) {
	r := fiber.New()
	RegisterHandlers(r, &HandlerOpts{Protocol: &successfulProtocol{}, Logger: log.NoOpLogger()})
	request, _ := http.NewRequest(http.MethodHead, "/api/v1/github.com/skillsgo/skillsgo/versions/v1.2.3.zip", nil)
	response, err := r.Test(request)
	if err != nil {
		t.Fatal(err)
	}
	if response.StatusCode != http.StatusMethodNotAllowed || response.Header.Get("Allow") != http.MethodGet {
		t.Fatalf("HEAD returned status=%d Allow=%q", response.StatusCode, response.Header.Get("Allow"))
	}
}

func TestCanonicalVersionZipRedirectsToArtifactOrigin(t *testing.T) {
	r := fiber.New()
	RegisterHandlers(r, &HandlerOpts{
		Protocol:       &successfulProtocol{},
		Logger:         log.NoOpLogger(),
		ArtifactOrigin: "https://files.skillsgo.ai",
	})

	request, err := http.NewRequest(http.MethodGet, "/api/v1/github.com/skillsgo/skillsgo/versions/v1.2.3.zip", nil)
	if err != nil {
		t.Fatal(err)
	}
	response, err := r.Test(request)
	if err != nil {
		t.Fatal(err)
	}
	if response.StatusCode != http.StatusMovedPermanently {
		t.Fatalf("GET returned %d, want 301", response.StatusCode)
	}
	const expected = "https://files.skillsgo.ai/github.com/skillsgo/skillsgo/versions/v1.2.3.zip"
	if got := response.Header.Get("Location"); got != expected {
		t.Fatalf("GET Location = %q, want %q", got, expected)
	}
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

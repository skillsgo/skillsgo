/*
 * [INPUT]: Uses ephemeral Ed25519 keys and HTTP origins around Checker.
 * [OUTPUT]: Specifies authenticated update checks and rejection of tampered, oversized, cross-origin, malformed, or unsupported metadata.
 * [POS]: Serves as adversarial contract coverage for the CLI release trust boundary.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package selfupdate

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestCheckVerifiesSignedPlatformRelease(t *testing.T) {
	checker := fixtureChecker(t, func(origin string) Manifest { return validManifest(origin) }, false)
	result, err := checker.Check(context.Background(), "v1.0.0", "homebrew", "")
	require.NoError(t, err)
	require.Equal(t, "v1.1.0", result.LatestVersion)
	require.True(t, result.UpdateAvailable)
	require.Equal(t, "brew upgrade skillsgo", result.UpgradeCommand)
}

func TestCheckRejectsTamperedManifest(t *testing.T) {
	checker := fixtureChecker(t, func(origin string) Manifest { return validManifest(origin) }, true)
	_, err := checker.Check(context.Background(), "v1.0.0", "direct", "")
	require.ErrorContains(t, err, "signature is invalid")
}

func TestCheckRejectsCrossOriginArtifact(t *testing.T) {
	checker := fixtureChecker(t, func(origin string) Manifest {
		manifest := validManifest(origin)
		artifact := manifest.Artifacts["linux_amd64"]
		artifact.URL = "https://example.com/cli/versions/v1.1.0/skillsgo.tar.gz"
		manifest.Artifacts["linux_amd64"] = artifact
		return manifest
	}, false)
	_, err := checker.Check(context.Background(), "v1.0.0", "direct", "")
	require.ErrorContains(t, err, "untrusted CLI artifact URL")
}

func TestCheckRejectsUnsupportedPlatform(t *testing.T) {
	checker := fixtureChecker(t, func(origin string) Manifest { return validManifest(origin) }, false)
	checker.goarch = "arm64"
	_, err := checker.Check(context.Background(), "v1.0.0", "direct", "")
	require.ErrorContains(t, err, "does not support linux_arm64")
}

func TestVersionSpecificCheckRequiresExactManifestVersion(t *testing.T) {
	checker := fixtureChecker(t, func(origin string) Manifest { return validManifest(origin) }, false)
	_, err := checker.Check(context.Background(), "v1.0.0", "direct", "v1.2.0")
	require.ErrorContains(t, err, "version mismatch")
}

func TestCheckRejectsCrossOriginRedirect(t *testing.T) {
	publicKey, _, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)
	destination := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, _ *http.Request) { _, _ = writer.Write([]byte("unexpected")) }))
	t.Cleanup(destination.Close)
	origin := httptest.NewServer(http.RedirectHandler(destination.URL, http.StatusFound))
	t.Cleanup(origin.Close)
	checker, err := NewChecker(origin.URL, publicKey, nil, "linux", "amd64")
	require.NoError(t, err)

	_, err = checker.Check(context.Background(), "v1.0.0", "direct", "")
	require.ErrorContains(t, err, "redirect left the trusted origin")
}

func TestCheckRejectsUnexpectedArtifactPathAndFallback(t *testing.T) {
	checker := fixtureChecker(t, func(origin string) Manifest {
		manifest := validManifest(origin)
		artifact := manifest.Artifacts["linux_amd64"]
		artifact.URL = origin + "/cli/versions/v1.1.0/other.tar.gz"
		manifest.Artifacts["linux_amd64"] = artifact
		return manifest
	}, false)
	_, err := checker.Check(context.Background(), "v1.0.0", "direct", "")
	require.ErrorContains(t, err, "untrusted CLI artifact URL")

	checker = fixtureChecker(t, func(origin string) Manifest {
		manifest := validManifest(origin)
		manifest.GitHubRelease = "https://example.com/release"
		return manifest
	}, false)
	_, err = checker.Check(context.Background(), "v1.0.0", "direct", "")
	require.ErrorContains(t, err, "untrusted CLI GitHub Release URL")
}

func validManifest(origin string) Manifest {
	return Manifest{SchemaVersion: 1, Version: "v1.1.0", PublishedAt: time.Date(2026, 8, 2, 0, 0, 0, 0, time.UTC).Format(time.RFC3339), Commit: "abcdef", Artifacts: map[string]Artifact{
		"linux_amd64": {URL: origin + "/cli/versions/v1.1.0/skillsgo_1.1.0_linux_amd64.tar.gz", SHA256: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", Size: 42},
	}}
}

func TestBundledCheckStopsBeforeReadingUpdateMetadata(t *testing.T) {
	publicKey, _, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)
	checker, err := NewChecker("https://updates.example.com", publicKey, nil, "darwin", "arm64")
	require.NoError(t, err)

	_, err = checker.Check(context.Background(), "0.0.2", "bundled", "")

	require.ErrorContains(t, err, "owned by the SkillsGo App")
}

func fixtureChecker(t *testing.T, manifest func(string) Manifest, tamper bool) *Checker {
	t.Helper()
	publicKey, privateKey, err := ed25519.GenerateKey(rand.Reader)
	require.NoError(t, err)
	var server *httptest.Server
	server = httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		body, marshalErr := json.Marshal(manifest(server.URL))
		require.NoError(t, marshalErr)
		switch request.URL.Path {
		case "/cli/stable/manifest.json", "/cli/versions/v1.2.0/manifest.json":
			if tamper {
				body = append(body, ' ')
			}
			_, _ = writer.Write(body)
		case "/cli/stable/manifest.sig", "/cli/versions/v1.2.0/manifest.sig":
			_, _ = writer.Write(ed25519.Sign(privateKey, mustJSON(t, manifest(server.URL))))
		default:
			http.NotFound(writer, request)
		}
	}))
	t.Cleanup(server.Close)
	checker, err := NewChecker(server.URL, publicKey, server.Client(), "linux", "amd64")
	require.NoError(t, err)
	return checker
}

func mustJSON(t *testing.T, value any) []byte {
	t.Helper()
	data, err := json.Marshal(value)
	require.NoError(t, err)
	return data
}

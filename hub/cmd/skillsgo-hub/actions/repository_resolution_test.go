/*
 * [INPUT]: Uses the Fiber Router, shared Repository resolution DTOs, typed Selector grammar, and a recording resolver seam.
 * [OUTPUT]: Specifies strict add-time branch/commit resolution, immutable response identity, and rejection of latest, ranges, unknown fields, and trailing JSON.
 * [POS]: Serves as the HTTP Router contract for mutable Repository resolution outside the immutable root Proxy.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gofiber/fiber/v3"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
	"github.com/stretchr/testify/require"
)

type recordingRepositoryResolver struct {
	repositoryID string
	selector     string
}

func (resolver *recordingRepositoryResolver) ResolveRepository(_ context.Context, repositoryID, selector string) (protocolapi.RepositoryInfo, error) {
	resolver.repositoryID, resolver.selector = repositoryID, selector
	return protocolapi.RepositoryInfo{SchemaVersion: 1, Kind: protocolapi.KindRepository, ID: repositoryID,
		Version: "v1.2.4-0.20260723010000-abcdef123456", Time: time.Date(2026, 7, 23, 1, 0, 0, 0, time.UTC),
		Ref: "refs/heads/feature/deep", CommitSHA: "abcdef1234567890"}, nil
}

func TestRepositoryResolutionRouteResolvesSlashBranchToImmutableVersion(t *testing.T) {
	resolver := &recordingRepositoryResolver{}
	app := fiber.New()
	registerRepositoryResolutionRoute(app, resolver)
	body, err := json.Marshal(protocolapi.RepositoryResolutionRequest{SchemaVersion: 1, RepositoryID: "github.com/example/skills", Selector: "feature/deep"})
	require.NoError(t, err)
	response, err := app.Test(httptest.NewRequest(http.MethodPost, "/api/v1/repository-resolutions", bytes.NewReader(body)))
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, response.StatusCode)
	require.Equal(t, "github.com/example/skills", resolver.repositoryID)
	require.Equal(t, "feature/deep", resolver.selector)
	encoded, err := io.ReadAll(response.Body)
	require.NoError(t, err)
	var resolved protocolapi.RepositoryResolutionResponse
	require.NoError(t, json.Unmarshal(encoded, &resolved))
	require.Equal(t, "v1.2.4-0.20260723010000-abcdef123456", resolved.Version)
}

func TestRepositoryResolutionRouteRejectsNonClosedInputs(t *testing.T) {
	for _, body := range []string{
		`{"schemaVersion":1,"repositoryId":"github.com/example/skills","selector":"latest"}`,
		`{"schemaVersion":1,"repositoryId":"github.com/example/skills","selector":"^1.2.3"}`,
		`{"schemaVersion":1,"repositoryId":"github.com/example/skills","selector":"main","extra":true}`,
		`{"schemaVersion":1,"repositoryId":"github.com/example/skills","selector":"main"} {}`,
	} {
		app := fiber.New()
		registerRepositoryResolutionRoute(app, &recordingRepositoryResolver{})
		response, err := app.Test(httptest.NewRequest(http.MethodPost, "/api/v1/repository-resolutions", bytes.NewBufferString(body)))
		require.NoError(t, err)
		require.Equal(t, http.StatusBadRequest, response.StatusCode, body)
	}
}

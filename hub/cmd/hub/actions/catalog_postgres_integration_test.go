/*
 * [INPUT]: Uses the public Hub router with an opt-in Testcontainers PostgreSQL Catalog.
 * [OUTPUT]: Specifies PostgreSQL-backed pagination and empty collection response parity at the HTTP boundary.
 * [POS]: Serves as database-portability coverage for the stable Hub discovery wire contract.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/stretchr/testify/require"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
)

// TestCatalogAPIPostgresProtocol runs only when explicitly requested so the
// normal Hub suite does not require Docker.
func TestCatalogAPIPostgresProtocol(t *testing.T) {
	if os.Getenv("SKILLSGO_TEST_POSTGRES") != "1" {
		t.Skip("set SKILLSGO_TEST_POSTGRES=1 to run the PostgreSQL integration test")
	}
	ctx := context.Background()
	container, err := postgres.Run(ctx, "postgres:17-alpine",
		postgres.WithDatabase("skillsgo"),
		postgres.WithUsername("skillsgo"),
		postgres.WithPassword("skillsgo"),
		postgres.BasicWaitStrategies(),
	)
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, container.Terminate(ctx)) })

	dsn, err := container.ConnectionString(ctx, "sslmode=disable")
	require.NoError(t, err)
	metadata, err := catalog.Open(ctx, config.DatabaseConfig{
		Type: "postgres", DSN: dsn, MaxOpenConns: 5, MaxIdleConns: 2,
	})
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, metadata.Close()) })
	router := newFiberApp()
	registerCatalogAPIRoutes(router, metadata, nil)

	for _, name := range []string{"alpha", "bravo", "charlie"} {
		require.NoError(t, metadata.UpsertSkill(ctx, &catalog.Skill{
			SkillID: "github.com/acme/skills/-/" + name,
			Name:    name, Description: "Agent capability", LatestVersion: "main",
		}))
	}

	first := httptest.NewRecorder()
	serveFiber(t, router, first, httptest.NewRequest(http.MethodGet, "/v1/search?q=capability&limit=2", nil))
	require.Equal(t, http.StatusOK, first.Code)
	var page skillsResponse
	require.NoError(t, json.NewDecoder(first.Body).Decode(&page))
	require.Equal(t, "search", page.Collection)
	require.Len(t, page.Skills, 2)
	require.Equal(t, 2, page.Page.Limit)
	require.Equal(t, 0, page.Page.Offset)
	require.NotNil(t, page.Page.NextOffset)
	require.Equal(t, 2, *page.Page.NextOffset)

	empty := httptest.NewRecorder()
	serveFiber(t, router, empty, httptest.NewRequest(http.MethodGet, "/v1/search?q=missing", nil))
	require.Equal(t, http.StatusOK, empty.Code)
	require.JSONEq(t, `{"collection":"search","skills":[],"page":{"limit":20,"offset":0,"nextOffset":null}}`, empty.Body.String())
}

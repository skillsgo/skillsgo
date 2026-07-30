/*
 * [INPUT]: Exercises assembled Fiber routes with global, Admin-only, overlapping, and absent Hub Basic Auth configuration.
 * [OUTPUT]: Specifies externally visible administration-route protection without changing public-route availability.
 * [POS]: Serves as Router-seam coverage for Hub administration authentication in the actions module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"bytes"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/stretchr/testify/require"
)

func TestAdministrationAuthenticationScopesRoutes(t *testing.T) {
	tests := []struct {
		name           string
		config         config.Config
		publicStatus   int
		adminStatus    int
		adminUser      string
		adminPass      string
		wantAdminRoute bool
		wantWarning    bool
	}{
		{name: "unconfigured", config: config.Config{}, publicStatus: http.StatusOK, adminStatus: http.StatusNotFound},
		{name: "admin only", config: config.Config{AdminAuthUser: "admin", AdminAuthPass: "secret"}, publicStatus: http.StatusOK, adminStatus: http.StatusOK, adminUser: "admin", adminPass: "secret", wantAdminRoute: true},
		{name: "global", config: config.Config{BasicAuthUser: "global", BasicAuthPass: "secret"}, publicStatus: http.StatusUnauthorized, adminStatus: http.StatusOK, adminUser: "global", adminPass: "secret", wantAdminRoute: true},
		{name: "global wins", config: config.Config{BasicAuthUser: "global", BasicAuthPass: "secret", AdminAuthUser: "admin", AdminAuthPass: "ignored"}, publicStatus: http.StatusUnauthorized, adminStatus: http.StatusOK, adminUser: "global", adminPass: "secret", wantAdminRoute: true, wantWarning: true},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			var logs bytes.Buffer
			logger := log.NewWithOutput(&logs, "none", slog.LevelDebug, "plain")
			app := fiber.New()
			admin, enabled := configureAdministrationAuthentication(app, &test.config, logger)
			require.Equal(t, test.wantAdminRoute, enabled)
			if enabled {
				admin.Get("/probe", func(c fiber.Ctx) error { return c.SendStatus(fiber.StatusOK) })
			}
			app.Get("/public", func(c fiber.Ctx) error { return c.SendStatus(fiber.StatusOK) })

			publicRequest, _ := http.NewRequest(http.MethodGet, "/public", nil)
			publicResponse, err := app.Test(publicRequest)
			require.NoError(t, err)
			require.Equal(t, test.publicStatus, publicResponse.StatusCode)

			adminRequest, _ := http.NewRequest(http.MethodGet, "/api/v1/admin/probe", nil)
			if test.adminUser != "" {
				adminRequest.SetBasicAuth(test.adminUser, test.adminPass)
			}
			adminResponse, err := app.Test(adminRequest)
			require.NoError(t, err)
			require.Equal(t, test.adminStatus, adminResponse.StatusCode)
			require.Equal(t, test.wantWarning, strings.Contains(logs.String(), "Admin Basic Auth credentials are ignored"))
		})
	}
}

func TestAdministrationAuthenticationUsesConfiguredRoutePrefix(t *testing.T) {
	app := fiber.New()
	prefixed := app.Group("/hub")
	admin, enabled := configureAdministrationAuthentication(prefixed, &config.Config{AdminAuthUser: "admin", AdminAuthPass: "secret"}, log.NoOpLogger())
	require.True(t, enabled)
	admin.Get("/probe", func(c fiber.Ctx) error { return c.SendStatus(fiber.StatusOK) })

	unprefixed, err := app.Test(httptest.NewRequest(http.MethodGet, "/api/v1/admin/probe", nil))
	require.NoError(t, err)
	require.Equal(t, http.StatusNotFound, unprefixed.StatusCode)
	prefixedRequest := httptest.NewRequest(http.MethodGet, "/hub/api/v1/admin/probe", nil)
	prefixedRequest.SetBasicAuth("admin", "secret")
	prefixedResponse, err := app.Test(prefixedRequest)
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, prefixedResponse.StatusCode)
}

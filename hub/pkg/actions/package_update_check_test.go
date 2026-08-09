/*
 * [INPUT]: Uses the public Hub router and a deterministic Package update checker.
 * [OUTPUT]: Specifies the user-triggered Package update-check HTTP contract for unchanged and newly resolved upstream Versions.
 * [POS]: Serves as executable public API coverage for manually checking one Package's upstream latest Version.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	"github.com/skillsgo/skillsgo/hub/pkg/skill"
	"github.com/skillsgo/skillsgo/hub/pkg/taskqueue"
	"github.com/stretchr/testify/require"
)

type packageUpdateCheckerStub struct {
	result packageUpdateCheckResult
	err    error
	paths  []string
}

func (stub *packageUpdateCheckerStub) CheckUpdate(_ context.Context, packagePath string) (packageUpdateCheckResult, error) {
	stub.paths = append(stub.paths, packagePath)
	return stub.result, stub.err
}

func TestPackageUpdateCheckReturnsUpToDateThroughThePublicAPI(t *testing.T) {
	checker := &packageUpdateCheckerStub{result: packageUpdateCheckResult{
		PackagePath: "github.com/acme/skills",
		Status:      packageUpdateCheckUpToDate,
		Version:     "v1.1.0",
	}}
	app := fiber.New()
	registerPackageUpdateCheckRoute(app, checker)
	body, err := json.Marshal(map[string]any{
		"schemaVersion": 1,
		"packagePath":   "github.com/acme/skills",
	})
	require.NoError(t, err)

	response, err := app.Test(httptest.NewRequest(http.MethodPost, "/api/v1/packages/update-checks", bytes.NewReader(body)))
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, response.StatusCode)
	var document map[string]any
	require.NoError(t, json.NewDecoder(response.Body).Decode(&document))
	require.Equal(t, map[string]any{
		"schemaVersion": float64(1),
		"packagePath":   "github.com/acme/skills",
		"status":        "up_to_date",
		"version":       "v1.1.0",
	}, document)
	require.Equal(t, []string{"github.com/acme/skills"}, checker.paths)
}

func TestPackageUpdateCheckQueuesTheExactNewVersionThroughThePublicAPI(t *testing.T) {
	metadata := &latestSyncCatalogStub{versions: map[string]catalog.PackageVersion{}}
	resolver := &latestSyncResolverStub{resolutions: map[string]skill.Resolution{
		"github.com/acme/skills": {Version: "v1.2.0", CommitSHA: "commit-v1.2.0"},
	}}
	materializer := &latestSyncMaterializerStub{}
	runtime := taskqueue.NewSynchronous()
	checker := newPackageLatestSyncService(metadata, runtime, resolver, materializer, 0)
	require.NoError(t, checker.Register())
	require.NoError(t, runtime.Start(t.Context()))
	t.Cleanup(func() { require.NoError(t, runtime.Stop(context.Background())) })
	app := fiber.New()
	registerPackageUpdateCheckRoute(app, checker)
	body := bytes.NewBufferString(`{"schemaVersion":1,"packagePath":"github.com/acme/skills"}`)

	response, err := app.Test(httptest.NewRequest(http.MethodPost, "/api/v1/packages/update-checks", body))
	require.NoError(t, err)
	require.Equal(t, http.StatusOK, response.StatusCode)
	var document packageUpdateCheckResult
	require.NoError(t, json.NewDecoder(response.Body).Decode(&document))
	require.Equal(t, packageUpdateCheckResult{
		SchemaVersion: 1,
		PackagePath:   "github.com/acme/skills",
		Status:        packageUpdateCheckUpdating,
		Version:       "v1.2.0",
	}, document)
	require.Eventually(t, func() bool {
		return len(materializer.callHistory()) == 1
	}, time.Second, 10*time.Millisecond)
	require.Equal(t, []string{"github.com/acme/skills@v1.2.0#commit-v1.2.0"}, materializer.callHistory())
}

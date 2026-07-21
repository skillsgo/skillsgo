/*
 * [INPUT]: Uses an HTTP test server implementing the protected skills.sh bridge response contract.
 * [OUTPUT]: Specifies exact endpoint use, bearer authentication, all-time request parameters, and response decoding.
 * [POS]: Serves as network-adapter contract coverage for skills.sh synchronization.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillssh

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestClientUsesConfiguredEndpointAndBearerToken(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(response http.ResponseWriter, request *http.Request) {
		require.Equal(t, "/api/skills", request.URL.Path)
		require.Equal(t, "Bearer shared-secret", request.Header.Get("Authorization"))
		var payload map[string]any
		require.NoError(t, json.NewDecoder(request.Body).Decode(&payload))
		require.Equal(t, "all-time", payload["view"])
		_, _ = response.Write([]byte(`{"fetchedAt":"2026-07-21T12:00:00Z","pages":[{"page":0,"status":200,"body":{"data":[{"id":"a/b/skill","source":"a/b","slug":"skill","installs":12}],"pagination":{"page":0,"total":1,"hasMore":false}}}]}`))
	}))
	t.Cleanup(server.Close)

	pages, observedAt, err := NewClient(server.URL+"/api/skills", "shared-secret", time.Second).Fetch(context.Background(), 0, 1, 500)
	require.NoError(t, err)
	require.Equal(t, time.Date(2026, time.July, 21, 12, 0, 0, 0, time.UTC), observedAt)
	require.Len(t, pages, 1)
	require.Equal(t, int64(12), pages[0].Data[0].Installs)
}

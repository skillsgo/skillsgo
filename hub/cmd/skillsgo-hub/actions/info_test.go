/*
 * [INPUT]: Uses the Fiber info route with validated selfhost and cloud deployment configuration.
 * [OUTPUT]: Specifies the minimal mode response and conditional normalized Cloud origin.
 * [POS]: Serves as executable coverage for Hub deployment discovery.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/stretchr/testify/require"
)

func TestInfoRoute(t *testing.T) {
	for _, test := range []struct {
		name string
		conf config.Config
		want string
	}{
		{name: "selfhost", conf: config.Config{Mode: "selfhost"}, want: `{"mode":"selfhost"}`},
		{name: "cloud", conf: config.Config{Mode: "cloud", CloudOrigin: "https://cloud.skillsgo.ai/"}, want: `{"mode":"cloud","cloud":"https://cloud.skillsgo.ai"}`},
	} {
		t.Run(test.name, func(t *testing.T) {
			app := newFiberApp()
			registerInfoRoute(app, &test.conf)
			response, err := app.Test(httptest.NewRequest(http.MethodGet, "/api/v1/info", nil))
			require.NoError(t, err)
			body, err := io.ReadAll(response.Body)
			require.NoError(t, err)
			require.JSONEq(t, test.want, string(body))
		})
	}
}

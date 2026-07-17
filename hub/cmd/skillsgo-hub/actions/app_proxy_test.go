/*
 * [INPUT]: Depends on the actions package imports and contracts declared in this file.
 * [OUTPUT]: Specifies the actions package behavior covered by app_proxy_test.go.
 * [POS]: Serves as test coverage for the actions package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"text/template"

	"github.com/skillsgo/skillsgo/hub/pkg/build"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/storage/mem"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

type routeTest struct {
	method string
	path   string
	body   string
	test   func(t *testing.T, req *http.Request, resp *http.Response)
}

func TestProxyRoutes(t *testing.T) {
	r := newFiberApp()
	s, err := mem.NewStorage()
	require.NoError(t, err)
	l := log.NoOpLogger()
	c, err := config.Load("")
	require.NoError(t, err)
	c.PathPrefix = "/prefix"
	subRouter := r.Group(c.PathPrefix)
	err = addProxyRoutes(subRouter, s, l, c)
	require.NoError(t, err)

	baseURL := "https://athens.azurefd.net" + c.PathPrefix

	testCases := []routeTest{
		{"GET", "/", "", func(t *testing.T, req *http.Request, resp *http.Response) {
			assert.Equal(t, http.StatusOK, resp.StatusCode)
			body, err := io.ReadAll(resp.Body)
			require.NoError(t, err)
			tmp, err := template.New("home").Parse(homepage)
			assert.NoError(t, err)

			templateData := make(map[string]string)

			templateData["Host"] = req.Host

			if !strings.HasPrefix(templateData["Host"], "http://") && !strings.HasPrefix(templateData["Host"], "https://") {
				if req.TLS != nil {
					templateData["Host"] = "https://" + templateData["Host"]
				} else {
					templateData["Host"] = "http://" + templateData["Host"]
				}
			}

			var expected strings.Builder
			err = tmp.ExecuteTemplate(&expected, "home", templateData)
			require.NoError(t, err)

			assert.Equal(t, expected.String(), string(body))
		}},
		{"GET", "/badz", "", func(t *testing.T, req *http.Request, resp *http.Response) {
			assert.Equal(t, http.StatusNotFound, resp.StatusCode)
		}},
		{"GET", "/healthz", "", func(t *testing.T, req *http.Request, resp *http.Response) {
			assert.Equal(t, http.StatusOK, resp.StatusCode)
		}},
		{"GET", "/readyz", "", func(t *testing.T, req *http.Request, resp *http.Response) {
			assert.Equal(t, http.StatusOK, resp.StatusCode)
		}},
		{"GET", "/version", "", func(t *testing.T, req *http.Request, resp *http.Response) {
			assert.Equal(t, http.StatusOK, resp.StatusCode)
			details := build.Details{}
			err := json.NewDecoder(resp.Body).Decode(&details)
			require.NoError(t, err)
			assert.EqualValues(t, build.Data(), details)
		}},
	}

	for _, tc := range testCases {
		req := httptest.NewRequest(
			tc.method,
			baseURL+tc.path,
			strings.NewReader(tc.body),
		)
		t.Run(req.RequestURI, func(t *testing.T) {
			w := httptest.NewRecorder()
			serveFiber(t, r, w, req)
			tc.test(t, req, w.Result())
		})
	}
}

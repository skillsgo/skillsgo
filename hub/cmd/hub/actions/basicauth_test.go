/*
 * [INPUT]: Depends on the actions package imports and contracts declared in this file.
 * [OUTPUT]: Specifies the actions package behavior covered by basicauth_test.go.
 * [POS]: Serves as test coverage for the actions package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"bytes"
	"log/slog"
	"net/http"
	"strings"
	"testing"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
)

var basicAuthTests = [...]struct {
	name           string
	user           string
	pass           string
	path           string
	logs           string
	expectedStatus int
}{
	{
		name:           "happy_path",
		user:           "correctUser",
		pass:           "correctPass",
		path:           "/",
		logs:           "",
		expectedStatus: 200,
	},
	{
		name:           "incorrect_username",
		user:           "wrongUser",
		pass:           "correctPass",
		path:           "/",
		logs:           "",
		expectedStatus: 401,
	},
	{
		name:           "incorrect_password",
		user:           "correctUser",
		pass:           "wrongPassword",
		path:           "/",
		logs:           "",
		expectedStatus: 401,
	},
	{
		name:           "log_on_healthz",
		user:           "wrongUser",
		pass:           "wrongPassword",
		path:           "/healthz",
		logs:           "",
		expectedStatus: 200,
	},
	{
		name:           "log_on_readyz",
		user:           "wrongUser",
		pass:           "wrongPassword",
		path:           "/readyz",
		logs:           "",
		expectedStatus: 200,
	},
}

func TestBasicAuth(t *testing.T) {
	mwFunc := basicAuth("correctUser", "correctPass")
	for _, tc := range basicAuthTests {
		t.Run(tc.name, func(t *testing.T) {
			app := fiber.New()
			app.Use(mwFunc)
			app.Get("/*", func(c fiber.Ctx) error { return c.SendStatus(fiber.StatusOK) })
			r, _ := http.NewRequest(http.MethodGet, tc.path, nil)
			r.SetBasicAuth(tc.user, tc.pass)
			buf := &bytes.Buffer{}
			lggr := log.NewWithOutput(buf, "none", slog.LevelDebug, "")
			_ = lggr
			resp, err := app.Test(r)
			if err != nil {
				t.Fatal(err)
			}
			if resp.StatusCode != tc.expectedStatus {
				t.Fatalf("expected http status to be %v but got %v", tc.expectedStatus, resp.StatusCode)
			}
			if !strings.Contains(buf.String(), tc.logs) {
				t.Fatalf("expected logs to include: %s but got: %s", tc.logs, buf.String())
			}
		})
	}
}

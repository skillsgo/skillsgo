/*
 * [INPUT]: Depends on the middleware package imports and contracts declared in this file.
 * [OUTPUT]: Specifies the middleware package behavior covered by requestid_test.go.
 * [POS]: Serves as test coverage for the middleware package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package middleware

import (
	"net/http"
	"testing"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"
	"github.com/skillsgo/skillsgo/hub/pkg/requestid"
)

func TestWithRequestID(t *testing.T) {
	var givenRequestID string
	app := fiber.New()
	app.Use(WithRequestID)
	app.Get("/", func(c fiber.Ctx) error {
		givenRequestID = requestid.FromContext(c.Context())
		return nil
	})
	req, _ := http.NewRequest("GET", "/", nil)
	expectedRequestID := uuid.New().String()
	req.Header.Set(requestid.HeaderKey, expectedRequestID)
	if _, err := app.Test(req); err != nil {
		t.Fatal(err)
	}
	if givenRequestID != expectedRequestID {
		t.Fatalf("expected request id to be %q but got %q", expectedRequestID, givenRequestID)
	}
	req, _ = http.NewRequest("GET", "/", nil)
	if _, err := app.Test(req); err != nil {
		t.Fatal(err)
	}
	if givenRequestID == "" {
		t.Fatal("expected a request id to be created when a request id header is empty")
	}
}

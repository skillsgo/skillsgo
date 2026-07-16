/*
 * [INPUT]: Depends on the middleware package imports and contracts declared in this file.
 * [OUTPUT]: Provides the middleware package behavior implemented by request.go.
 * [POS]: Serves as maintained source in the middleware package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package middleware

import (
	"fmt"
	"net/http"

	"github.com/fatih/color"
	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
)

// Middleware decorates a standard HTTP handler.
type Middleware = fiber.Handler

// RequestLogger logs request params to standard output
// it should only be used during dev.
func RequestLogger(c fiber.Ctx) error {
	err := c.Next()
	log.EntryFromContext(c.Context()).WithFields(map[string]any{
		"http-status": fmtResponseCode(c.Response().StatusCode()),
	}).Infof("incoming request")
	return err
}

func fmtResponseCode(statusCode int) string {
	if statusCode == 0 {
		statusCode = 200
	}
	status := fmt.Sprint(statusCode)
	switch {
	case statusCode < http.StatusBadRequest:
		status = color.GreenString("%v", status)
	case statusCode >= http.StatusBadRequest && statusCode < http.StatusInternalServerError:
		status = color.HiYellowString("%v", status)
	default:
		status = color.HiRedString("%v", status)
	}
	return status
}

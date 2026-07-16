/*
 * [INPUT]: Depends on Fiber request context, decoded artifact paths, and an external HTTP validation webhook.
 * [OUTPUT]: Provides native Fiber middleware that validates versioned artifact requests.
 * [POS]: Serves as the optional external-validation policy layer in the Hub request stack.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package middleware

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/paths"
)

// NewValidationMiddleware builds a middleware function that performs validation checks by calling
// an external webhook.
func NewValidationMiddleware(client *http.Client, validatorHook string) Middleware {
	return func(c fiber.Ctx) error {
		requestPath := string(c.Request().URI().Path())
		skill, err := paths.GetSkill(requestPath)
		if err != nil {
			// if there is no module the path we are hitting is not one related to modules, like /
			return c.Next()
		}
		ctx := c.Context()
		// not checking the error. Not all requests include a version
		// i.e. list requests path is like /{skill:.+}/@v/list with no version parameter
		version, _ := paths.GetVersion(requestPath)
		if version != "" {
			response, err := validate(ctx, client, validatorHook, skill, version)
			if err != nil {
				entry := log.EntryFromContext(ctx)
				entry.SystemErr(err)
				return c.SendStatus(fiber.StatusInternalServerError)
			}

			maybeLogValidationReason(ctx, string(response.Message), skill, version)

			if !response.Valid {
				return c.SendStatus(fiber.StatusForbidden)
			}
		}
		return c.Next()
	}
}

func maybeLogValidationReason(context context.Context, message, mod, version string) {
	if len(message) > 0 {
		entry := log.EntryFromContext(context)
		entry.Warnf("error validating %s@%s %s", mod, version, message)
	}
}

type validationParams struct {
	Skill   string
	Version string
}

type validationResponse struct {
	Valid   bool
	Message []byte
}

func validate(ctx context.Context, client *http.Client, hook, mod, ver string) (validationResponse, error) {
	const op errors.Op = "actions.validate"

	toVal := &validationParams{mod, ver}
	jsonVal, err := json.Marshal(toVal)
	if err != nil {
		return validationResponse{Valid: false}, errors.E(op, err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, hook, bytes.NewReader(jsonVal))
	if err != nil {
		return validationResponse{}, errors.E(op, err)
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		return validationResponse{Valid: false}, errors.E(op, err)
	}
	defer func() {
		_, _ = io.Copy(io.Discard, resp.Body)
		_ = resp.Body.Close()
	}()

	switch resp.StatusCode {
	case http.StatusOK:
		return validationResponseFromRequest(resp), nil
	case http.StatusForbidden:
		return validationResponseFromRequest(resp), nil
	default:
		return validationResponse{Valid: false}, errors.E(op, "Unexpected status code ", resp.StatusCode)
	}
}

func validationResponseFromRequest(resp *http.Response) validationResponse {
	body, _ := io.ReadAll(resp.Body)
	return validationResponse{Valid: resp.StatusCode == http.StatusOK, Message: body}
}

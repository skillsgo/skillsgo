/*
 * [INPUT]: Depends on a Package-scoped upstream update checker and strict public JSON requests.
 * [OUTPUT]: Provides POST /api/v1/packages/update-checks with stable up_to_date or updating results.
 * [POS]: Serves as the user-triggered HTTP boundary for checking one Package's upstream latest Version.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"context"
	"encoding/json"
	"strings"

	"github.com/gofiber/fiber/v3"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
)

const (
	packageUpdateCheckUpToDate = protocolapi.PackageUpdateUpToDate
	packageUpdateCheckUpdating = protocolapi.PackageUpdateUpdating
)

type packageUpdateCheckRequest = protocolapi.PackageUpdateCheckRequest
type packageUpdateCheckResult = protocolapi.PackageUpdateCheckResult

type packageUpdateChecker interface {
	CheckUpdate(context.Context, string) (packageUpdateCheckResult, error)
}

func registerPackageUpdateCheckRoute(router fiber.Router, checker packageUpdateChecker) {
	router.Post("/api/v1/packages/update-checks", func(c fiber.Ctx) error {
		var request packageUpdateCheckRequest
		decoder := json.NewDecoder(strings.NewReader(string(c.Body())))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&request); err != nil || !request.Valid() {
			return writeAPIError(c, fiber.StatusBadRequest, "packagePath must be one canonical Package Path")
		}
		result, err := checker.CheckUpdate(c.Context(), request.PackagePath)
		if err != nil {
			return writeInternalAPIError(c, "package.check_update", fiber.StatusInternalServerError, "update_check_failed", "Package update check failed", err)
		}
		result.SchemaVersion = 1
		return writeJSON(c, fiber.StatusOK, result)
	})
}

/*
 * [INPUT]: Depends on parsed artifact coordinates, shared Version Query validation, Protocol Info resolution, configured or request-derived Artifact origins, and conditional cache policy.
 * [OUTPUT]: Resolves exact or movable revisions and serves canonical immutable Package Info JSON with an absolute Artifact Repository URL.
 * [POS]: Serves as the unified revision-to-Package-Info HTTP boundary in the Package distribution protocol.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package download

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	protocolversion "github.com/skillsgo/skillsgo/protocol/version"
)

// PathVersionInfo URL.
const PathVersionInfo = "/{repository:.+}/versions/{version}"

// InfoHandler implements GET baseURL/api/v1/{packagePath}/versions/{version}.
func InfoHandler(dp Protocol, lggr log.Entry, artifactOrigin string) fiber.Handler {
	const op errors.Op = "download.InfoHandler"
	return func(c fiber.Ctx) error {
		c.Set(fiber.HeaderContentType, fiber.MIMEApplicationJSONCharsetUTF8)
		mod, ver, err := getSkillParams(c, op)
		if err != nil {
			lggr.SystemErr(err)
			return c.SendStatus(errors.Kind(err))
		}
		query, err := protocolversion.ParseQuery(ver)
		if err != nil {
			return c.Status(fiber.StatusBadRequest).SendString(err.Error())
		}
		protectMovableVersionResponse(c, query.Value)
		if !query.Movable() && immutableNotModified(c, mod, query.Value, "info") {
			return c.SendStatus(fiber.StatusNotModified)
		}
		info, err := dp.Info(c.Context(), mod, query.Value)
		if err != nil {
			severityLevel := errors.Expect(err, errors.KindNotFound, errors.KindRedirect)
			lggr.SystemErr(errors.E(op, err, errors.S(mod), errors.V(ver), severityLevel))
			return c.SendStatus(errors.Kind(err))
		}
		info, err = resolveArtifactRepository(info, artifactOrigin, c.BaseURL())
		if err != nil {
			lggr.SystemErr(errors.E(op, err, errors.S(mod), errors.V(ver)))
			return c.SendStatus(fiber.StatusInternalServerError)
		}
		return c.Send(info)
	}
}

func resolveArtifactRepository(info []byte, configuredOrigin, requestOrigin string) ([]byte, error) {
	var document map[string]json.RawMessage
	if err := json.Unmarshal(info, &document); err != nil {
		return nil, fmt.Errorf("decode Package Info: %w", err)
	}
	raw, ok := document["artifactRepository"]
	if !ok {
		return info, nil
	}
	var repository string
	if err := json.Unmarshal(raw, &repository); err != nil {
		return nil, fmt.Errorf("decode Artifact Repository: %w", err)
	}
	if !strings.HasPrefix(repository, "/") {
		return info, nil
	}
	origin := strings.TrimRight(configuredOrigin, "/")
	if origin == "" {
		origin = strings.TrimRight(requestOrigin, "/")
	}
	encoded, err := json.Marshal(origin + repository)
	if err != nil {
		return nil, fmt.Errorf("encode Artifact Repository: %w", err)
	}
	document["artifactRepository"] = encoded
	resolved, err := json.Marshal(document)
	if err != nil {
		return nil, fmt.Errorf("encode Package Info: %w", err)
	}
	return resolved, nil
}

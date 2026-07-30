/*
 * [INPUT]: Depends on Fiber, strict Cloud DTO validation, canonical locale vocabulary, request time, and the Hub community-data seam.
 * [OUTPUT]: Provides the always-present installation-event and all-time, trending, and hot ranking HTTP routes for official and self-hosted Hub deployments.
 * [POS]: Serves as the unified public HTTP adapter over injected persistent or empty community data.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"bytes"
	"encoding/json"
	"io"
	"strconv"
	"strings"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/community"
	"github.com/skillsgo/skillsgo/protocol/cloud"
	protocollocale "github.com/skillsgo/skillsgo/protocol/locale"
)

func registerCommunityRoutes(router fiber.Router, store community.Store, now func() time.Time) {
	if store == nil {
		empty := community.NewEmptyStore()
		store = empty
	}
	router.Post(cloud.InstallEventsPath, recordInstallHandler(store, now))
	router.Get(cloud.RankingsPath+":kind", rankingHandler(store, now))
}

func recordInstallHandler(store community.Store, now func() time.Time) fiber.Handler {
	return func(c fiber.Ctx) error {
		decoder := json.NewDecoder(bytes.NewReader(c.Body()))
		decoder.DisallowUnknownFields()
		var event cloud.InstallEvent
		if err := decoder.Decode(&event); err != nil {
			return writeCommunityError(c, fiber.StatusBadRequest, "invalid install event")
		}
		if err := decoder.Decode(&struct{}{}); err != io.EOF {
			return writeCommunityError(c, fiber.StatusBadRequest, "request must contain one JSON object")
		}
		if message := event.Validate(now()); message != "" {
			return writeCommunityError(c, fiber.StatusBadRequest, message)
		}
		response, err := store.RecordInstall(c.Context(), event)
		if err != nil {
			return writeCommunityError(c, fiber.StatusInternalServerError, "event recording failed")
		}
		return writeJSON(c, fiber.StatusAccepted, response)
	}
}

func rankingHandler(store community.Store, now func() time.Time) fiber.Handler {
	return func(c fiber.Ctx) error {
		kind := cloud.RankingKind(c.Params("kind"))
		page, perPage, paginationOK := communityPagination(c)
		lang, languageOK := communityLanguage(c)
		if !kind.Valid() || !paginationOK || !languageOK {
			return writeCommunityError(c, fiber.StatusBadRequest, "invalid ranking request")
		}
		response, err := store.Ranking(c.Context(), community.RankingQuery{
			Kind: kind, Page: page, PerPage: perPage, Lang: lang, Now: now(),
		})
		if err != nil {
			return writeCommunityError(c, fiber.StatusInternalServerError, "ranking failed")
		}
		if response.Skills == nil {
			response.Skills = []cloud.RankingSkill{}
		}
		return writeJSON(c, fiber.StatusOK, response)
	}
}

func communityLanguage(c fiber.Ctx) (string, bool) {
	raw := strings.TrimSpace(c.Query(cloud.RankingLangQuery))
	if raw == "" {
		return "", true
	}
	canonical, err := protocollocale.CanonicalSupported(raw)
	return canonical, err == nil && canonical == raw
}

func communityPagination(c fiber.Ctx) (int, int, bool) {
	page, perPage := 0, 20
	var err error
	if raw := c.Query("page"); raw != "" {
		page, err = strconv.Atoi(raw)
	}
	if err == nil {
		if raw := c.Query("perPage"); raw != "" {
			perPage, err = strconv.Atoi(raw)
		}
	}
	valid := err == nil && page >= 0 && perPage >= 1 && perPage <= 100
	if valid && page > int(^uint(0)>>1)/perPage {
		valid = false
	}
	return page, perPage, valid
}

func writeCommunityError(c fiber.Ctx, status int, message string) error {
	return writeJSON(c, status, cloud.ErrorResponse{Error: message})
}

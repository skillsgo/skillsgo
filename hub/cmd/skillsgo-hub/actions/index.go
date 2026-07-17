/*
 * [INPUT]: Depends on the actions package imports and contracts declared in this file.
 * [OUTPUT]: Provides the actions package behavior implemented by index.go.
 * [POS]: Serves as maintained source in the actions package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"bytes"
	"context"
	"encoding/json"
	"log/slog"
	"strconv"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/errors"
	"github.com/skillsgo/skillsgo/hub/pkg/index"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
)

// indexHandler implements GET baseURL/index.
func indexHandler(index index.Indexer) fiber.Handler {
	return func(c fiber.Ctx) error {
		ctx := c.Context()
		list, err := getIndexLines(ctx, c.Query("limit"), c.Query("since"), index)
		if err != nil {
			log.EntryFromContext(ctx).SystemErr(err)
			return c.Status(errors.Kind(err)).SendString(err.Error())
		}

		var body bytes.Buffer
		enc := json.NewEncoder(&body)
		for _, meta := range list {
			if err = enc.Encode(meta); err != nil {
				log.EntryFromContext(ctx).SystemErr(err)
				return c.Status(fiber.StatusInternalServerError).SendString(err.Error())
			}
		}
		c.Type("json", "utf-8")
		return c.Send(body.Bytes())
	}
}

func getIndexLines(ctx context.Context, limitStr, sinceStr string, index index.Indexer) ([]*index.Line, error) {
	const op errors.Op = "actions.IndexHandler"
	var (
		err   error
		limit = 2000
		since time.Time
	)
	if limitStr != "" {
		limit, err = strconv.Atoi(limitStr)
		if err != nil || limit <= 0 {
			return nil, errors.E(op, err, errors.KindBadRequest, slog.LevelInfo)
		}
	}
	if sinceStr != "" {
		since, err = time.Parse(time.RFC3339, sinceStr)
		if err != nil {
			return nil, errors.E(op, err, errors.KindBadRequest, slog.LevelInfo)
		}
	}
	list, err := index.Lines(ctx, since, limit)
	if err != nil {
		return nil, errors.E(op, err)
	}
	return list, nil
}

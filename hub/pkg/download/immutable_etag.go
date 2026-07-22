/*
 * [INPUT]: Depends on canonical immutable artifact coordinates and HTTP conditional request headers.
 * [OUTPUT]: Provides stable strong ETags and short-circuits matching immutable GET or HEAD requests with 304.
 * [POS]: Serves as the conditional-delivery helper shared by exact Info and ZIP protocol handlers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package download

import (
	"crypto/sha256"
	"encoding/hex"
	"strings"

	"github.com/gofiber/fiber/v3"
)

func immutableNotModified(c fiber.Ctx, resourceID, version, extension string) bool {
	digest := sha256.Sum256([]byte(resourceID + "\x00" + version + "\x00" + extension))
	etag := `"skillsgo-` + hex.EncodeToString(digest[:]) + `"`
	c.Set(fiber.HeaderETag, etag)
	for _, candidate := range strings.Split(c.Get(fiber.HeaderIfNoneMatch), ",") {
		candidate = strings.TrimSpace(candidate)
		if candidate == etag || candidate == "W/"+etag || candidate == "*" {
			return true
		}
	}
	return false
}

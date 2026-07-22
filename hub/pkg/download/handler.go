/*
 * [INPUT]: Depends on Fiber routing, download Protocol handlers, request-scoped logging, semantic-version validation, and cache-control middleware.
 * [OUTPUT]: Registers the native Fiber routes and provides movable-query HTTP cache protection for the artifact download protocol.
 * [POS]: Serves as the HTTP routing boundary for the Hub download package.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package download

import (
	"net/http"
	"net/url"
	"path"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/download/mode"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
	"github.com/skillsgo/skillsgo/hub/pkg/middleware"
	protocolversion "github.com/skillsgo/skillsgo/protocol/version"
)

const movableVersionCacheControl = "no-cache, no-store, must-revalidate"
const immutableVersionCacheControl = "public, max-age=31536000, immutable"

// ProtocolHandler is a function that takes all that it needs to return
// a ready-to-go http handler that serves up cmd/go's download protocol.
type ProtocolHandler func(dp Protocol, lggr log.Entry, df *mode.DownloadFile) fiber.Handler

// HandlerOpts are the generic options for a ProtocolHandler.
type HandlerOpts struct {
	Protocol     Protocol
	Logger       *log.Logger
	DownloadFile *mode.DownloadFile
}

// LogEntryHandler pulls a log entry from the request context. Thanks to the
// LogEntryMiddleware, we should have a log entry stored in the context for each
// request with request-specific fields. This will grab the entry and pass it to
// the protocol handlers.
func LogEntryHandler(ph ProtocolHandler, opts *HandlerOpts) fiber.Handler {
	return func(c fiber.Ctx) error {
		ent := log.EntryFromContext(c.Context())
		return ph(opts.Protocol, ent, opts.DownloadFile)(c)
	}
}

// RegisterHandlers is a convenience method that registers
// all the download protocol paths for you.
func RegisterHandlers(r fiber.Router, opts *HandlerOpts) {
	// If true, this would only panic at boot time, static nil checks anyone?
	if opts == nil || opts.Protocol == nil || opts.Logger == nil {
		panic("absolutely unacceptable handler opts")
	}
	noCache := middleware.FiberCacheControl(movableVersionCacheControl)
	registerMethods(r, "/mod/+/@v/list", http.MethodGet, noCache, LogEntryHandler(ListHandler, opts))
	registerMethods(r, "/mod/+/@head", http.MethodGet, noCache, LogEntryHandler(SelectorHandler("head"), opts))
	registerMethods(r, "/mod/+/@release", http.MethodGet, noCache, LogEntryHandler(SelectorHandler("release"), opts))
	registerMethods(r, "/mod/+/@v/:version.info", http.MethodGet, LogEntryHandler(InfoHandler, opts))
	zipHandler := LogEntryHandler(ZipHandler, opts)
	r.Get("/mod/+/@v/:version.zip", zipHandler)
	r.Head("/mod/+/@v/:version.zip", zipHandler)
	r.All("/mod/+/@v/:version.zip", methodNotAllowed(http.MethodGet+", "+http.MethodHead))
}

func protectMovableVersionResponse(c fiber.Ctx, version string) {
	if protocolversion.IsImmutable(version) {
		c.Set(fiber.HeaderCacheControl, immutableVersionCacheControl)
	} else {
		c.Set(fiber.HeaderCacheControl, movableVersionCacheControl)
	}
}

func registerMethods(r fiber.Router, path, allow string, handlers ...any) {
	if len(handlers) == 0 {
		panic("artifact protocol route requires a handler")
	}
	r.Get(path, handlers[0], handlers[1:]...)
	r.All(path, methodNotAllowed(allow))
}

func methodNotAllowed(allow string) fiber.Handler {
	return func(c fiber.Ctx) error {
		c.Set(fiber.HeaderAllow, allow)
		c.Set(fiber.HeaderContentType, fiber.MIMETextPlainCharsetUTF8)
		return c.Status(fiber.StatusMethodNotAllowed).SendString("method not allowed")
	}
}

func httpErrorText(err error) string {
	if err == nil {
		return "request failed"
	}
	return err.Error()
}

func getRedirectURL(base, downloadPath string) (string, error) {
	url, err := url.Parse(base)
	if err != nil {
		return "", err
	}
	url.Path = path.Join(url.Path, downloadPath)
	return url.String(), nil
}

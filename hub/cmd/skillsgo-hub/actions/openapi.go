/*
 * [INPUT]: Depends on Huma's Fiber adapter, deployment configuration, native Fiber route inventory, contextual HTML templating, and an embedded pinned Scalar asset whose path-variable encoder is adapted for hierarchical Package Paths.
 * [OUTPUT]: Provides non-cacheable Huma-generated OpenAPI 3.1, context-safe self-hosted Scalar HTML with literal Package Path slashes, immutable compressed assets, and product-route coverage validation.
 * [POS]: Serves as the typed documentation sidecar for native Fiber handlers without owning their execution.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"bytes"
	"compress/gzip"
	"crypto/sha512"
	_ "embed"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"html/template"
	"path"
	"sort"
	"strings"

	"github.com/danielgtaylor/huma/v2"
	"github.com/danielgtaylor/huma/v2/adapters/humafiber"
	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
)

//go:embed assets/scalar-1.63.0.js
var scalarStandalone []byte

//go:embed assets/scalar-1.63.0.js.gz
var scalarStandaloneGzip []byte

var scalarAssetETag string

var scalarPageTemplate = template.Must(template.New("scalar").Parse(`<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="referrer" content="no-referrer">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>SkillsGo Hub API Reference</title>
  </head>
  <body>
    <script id="api-reference" data-url="{{.SpecURL}}" data-configuration="{{.RendererConfig}}"></script>
    <script src="{{.ScriptURL}}"></script>
  </body>
</html>`))

func init() {
	const encodedPathVariable = "encodeURIComponent(lx(t,n))"
	const hierarchicalPathVariable = "encodeURIComponent(lx(t,n)).replace(/%2F/gi,`/`)"
	if bytes.Count(scalarStandalone, []byte(encodedPathVariable)) != 1 {
		panic("adapt Scalar hierarchical path variables: pinned encoder signature changed")
	}
	scalarStandalone = bytes.Replace(scalarStandalone, []byte(encodedPathVariable), []byte(hierarchicalPathVariable), 1)

	var compressed bytes.Buffer
	writer := gzip.NewWriter(&compressed)
	if _, err := writer.Write(scalarStandalone); err != nil {
		panic("compress adapted Scalar asset: " + err.Error())
	}
	if err := writer.Close(); err != nil {
		panic("finish adapted Scalar asset compression: " + err.Error())
	}
	scalarStandaloneGzip = compressed.Bytes()
	digest := sha512.Sum512(scalarStandalone)
	scalarAssetETag = `"sha512-` + base64.RawURLEncoding.EncodeToString(digest[:]) + `"`
}

func registerHubAPIDocs(app *fiber.App, router fiber.Router, conf *config.Config, adminEnabled bool) huma.API {
	humaConfig := huma.DefaultConfig("SkillsGo Hub API", "1.0.0")
	humaConfig.Info.Description = "Public Skill discovery, Package Version Queries, and immutable Package Version distribution."
	humaConfig.DocsPath = ""
	humaConfig.OpenAPIPath = "/openapi"
	humaConfig.SchemasPath = ""
	humaConfig.CreateHooks = nil
	if conf.PathPrefix != "" {
		humaConfig.Servers = []*huma.Server{{
			URL: conf.PathPrefix, Description: "Current " + conf.Environment + " Hub deployment",
		}}
	}
	openAPIPath := path.Join("/", conf.PathPrefix, "openapi")
	router.Use(func(c fiber.Ctx) error {
		if strings.HasPrefix(c.Path(), openAPIPath) {
			c.Set(fiber.HeaderCacheControl, "no-store")
		}
		return c.Next()
	})
	api := humafiber.NewWithGroup(app, router, humaConfig)
	documentHubOperations(api, adminEnabled)
	registerSelfHostedScalar(router, conf.PathPrefix, conf.Environment == "development")
	return api
}

func registerSelfHostedScalar(router fiber.Router, pathPrefix string, development bool) {
	specURL := path.Join("/", pathPrefix, "openapi.json")
	scriptURL := path.Join("/", pathPrefix, "docs/assets/scalar-1.63.0-skillsgo.1.js")
	rendererConfig, err := json.Marshal(map[string]any{
		"agent":                 map[string]bool{"disabled": true},
		"defaultHttpClient":     map[string]string{"targetKey": "shell", "clientKey": "curl"},
		"hideClientButton":      false,
		"hideTestRequestButton": !development,
		"mcp":                   map[string]bool{"disabled": true},
		"operationTitleSource":  "summary",
		"persistAuth":           false,
		"showSidebar":           true,
		"withDefaultFonts":      false,
	})
	if err != nil {
		panic("marshal Scalar API reference configuration: " + err.Error())
	}
	var rendered bytes.Buffer
	if err := scalarPageTemplate.Execute(&rendered, struct {
		SpecURL        string
		ScriptURL      string
		RendererConfig string
	}{specURL, scriptURL, string(rendererConfig)}); err != nil {
		panic("render Scalar API reference: " + err.Error())
	}
	body := rendered.String()

	router.Get("/docs", func(c fiber.Ctx) error {
		c.Set(fiber.HeaderContentSecurityPolicy, "default-src 'none'; base-uri 'none'; connect-src 'self'; "+
			"form-action 'none'; frame-ancestors 'none'; "+
			"script-src 'self' 'unsafe-eval'; style-src 'unsafe-inline'")
		c.Set(fiber.HeaderContentType, fiber.MIMETextHTMLCharsetUTF8)
		return c.SendString(body)
	})
	router.Get("/docs/assets/scalar-1.63.0-skillsgo.1.js", func(c fiber.Ctx) error {
		c.Set(fiber.HeaderETag, scalarAssetETag)
		c.Set(fiber.HeaderVary, fiber.HeaderAcceptEncoding)
		c.Set(fiber.HeaderContentType, fiber.MIMETextJavaScriptCharsetUTF8)
		c.Set(fiber.HeaderCacheControl, "public, max-age=31536000, immutable")
		if c.Get(fiber.HeaderIfNoneMatch) == scalarAssetETag {
			return c.SendStatus(fiber.StatusNotModified)
		}
		if strings.Contains(c.Get(fiber.HeaderAcceptEncoding), "gzip") {
			c.Set(fiber.HeaderContentEncoding, "gzip")
			return c.Send(scalarStandaloneGzip)
		}
		return c.Send(scalarStandalone)
	})
}

func validateDocumentedProductRoutes(app *fiber.App, api huma.API, pathPrefix string) error {
	documented := make(map[string]struct{})
	for routePath := range api.OpenAPI().Paths {
		if strings.HasPrefix(routePath, "/api/v1/") {
			documented[routePath] = struct{}{}
		}
	}
	prefix := strings.TrimSuffix(pathPrefix, "/")
	missing := make(map[string]struct{})
	for _, route := range app.GetRoutes(true) {
		routePath := route.Path
		if prefix != "" {
			routePath = strings.TrimPrefix(routePath, prefix)
		}
		if !strings.HasPrefix(routePath, "/api/v1/") {
			continue
		}
		if _, ok := documented[fiberPathToOpenAPI(routePath)]; !ok {
			missing[routePath] = struct{}{}
		}
	}
	if len(missing) == 0 {
		return nil
	}
	paths := make([]string, 0, len(missing))
	for routePath := range missing {
		paths = append(paths, routePath)
	}
	sort.Strings(paths)
	return fmt.Errorf("Hub product routes missing OpenAPI documentation: %s", strings.Join(paths, ", "))
}

func fiberPathToOpenAPI(routePath string) string {
	routePath = strings.ReplaceAll(routePath, "/+/", "/{packagePath}/")
	routePath = strings.ReplaceAll(routePath, ":version", "{version}")
	return routePath
}

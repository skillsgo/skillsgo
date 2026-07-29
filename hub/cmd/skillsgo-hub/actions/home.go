/*
 * [INPUT]: Depends on Hub configuration, request origin data, and an optional operator-provided HTML template.
 * [OUTPUT]: Serves the SkillsGo Hub landing page with Go-compatible Version Query and immutable artifact protocol examples.
 * [POS]: Serves as the human protocol-orientation surface for Package distribution and product API routes.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package actions

import (
	"bytes"
	"errors"
	"html/template"
	"os"
	"strings"

	"github.com/gofiber/fiber/v3"
	"github.com/skillsgo/skillsgo/hub/pkg/config"
	"github.com/skillsgo/skillsgo/hub/pkg/log"
)

const homepage = `<!DOCTYPE html>
<html>
<head>
	<meta charset="utf-8"></meta>
	<title>SkillsGo Hub</title>
	<style>
		body {
			font-family: Arial, sans-serif;
			margin: 20px;
		}

		pre {
				background-color: #f4f4f4;
				padding: 5px;
				border-radius: 5px;
				width: fit-content;
  				padding: 10px;
		}


		code {
			background-color: #f4f4f4;
			padding: 5px;
			border-radius: 5px;
		}

	</style>
</head>
<body>
	
	<h1>SkillsGo Hub</h1>

	<h2>Package distribution API</h2>
	<p>Immutable artifacts are published at the canonical Package Path.</p>

	<h3>List of versions</h3>
	<p>This endpoint returns published canonical semantic versions:</p>
	<pre>GET {{ .Host }}/api/v1/github.com/owner/repository/versions</pre>

	<h3>Version info</h3>
	<p>This endpoint returns information about a specific immutable Package Version:</p>
	<pre>GET {{ .Host }}/api/v1/github.com/owner/repository/versions/v1.0.0</pre>

	<h3>Immutable Package archive</h3>

	<h3>Package Version Query</h3>
	<pre>GET {{ .Host }}/api/v1/github.com/owner/repository/versions/main</pre>
	<p>Resolve an exact version, semantic-version prefix/comparison, branch, tag, commit, or <code>latest</code> before fetching an immutable artifact.</p>

</body>
</html>
`

func proxyHomeHandler(config *config.Config) fiber.Handler {
	return func(c fiber.Ctx) error {
		lggr := log.EntryFromContext(c.Context())

		templateData := make(map[string]string)

		templateContents := homepage

		// load the template from the file system if it exists, otherwise revert to default
		rawTemplateFileContents, err := os.ReadFile(config.HomeTemplatePath)
		if err != nil {
			if !errors.Is(err, os.ErrNotExist) {
				// this is some other error, log it and revert to default
				lggr.SystemErr(err)
			}
		} else {
			templateContents = string(rawTemplateFileContents)
		}

		// This should be correct in most cases. If it is not, users can supply their own template
		templateData["Host"] = c.Hostname()

		// if the host does not have a scheme, add one based on the request
		if !strings.HasPrefix(templateData["Host"], "http://") && !strings.HasPrefix(templateData["Host"], "https://") {
			if c.Protocol() == "https" || c.Get("X-Forwarded-Proto") == "https" {
				templateData["Host"] = "https://" + templateData["Host"]
			} else {
				templateData["Host"] = "http://" + templateData["Host"]
			}
		}

		tmp, err := template.New("home").Parse(templateContents)
		if err != nil {
			lggr.SystemErr(err)
			return c.SendStatus(fiber.StatusInternalServerError)
		}

		var body bytes.Buffer
		err = tmp.ExecuteTemplate(&body, "home", templateData)
		if err != nil {
			lggr.SystemErr(err)
			return c.SendStatus(fiber.StatusInternalServerError)
		}
		c.Type("html", "utf-8")
		return c.Send(body.Bytes())
	}
}

/*
 * [INPUT]: Depends on final localized Catalog Skill rows and public Skill card contracts.
 * [OUTPUT]: Provides the authoritative pure Catalog-to-public-card projection and source-host image policy shared by Hub HTTP and Cloud rankings.
 * [POS]: Serves as the reusable presentation boundary that prevents embedded runtimes from duplicating Hub card rules.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillcard

import (
	"net/url"
	"strings"

	"github.com/skillsgo/skillsgo/hub/pkg/catalog"
	protocolapi "github.com/skillsgo/skillsgo/protocol/api"
)

func Project(item catalog.Skill) protocolapi.FindSkill {
	return protocolapi.FindSkill{PackagePath: item.PackagePath, Name: item.Name, Description: item.Description,
		ImageURL: ImageURL(item.SourceHost, item.SourceRepository), Path: item.Path, LatestVersion: item.LatestVersion}
}

func ImageURL(sourceHost, repository string) *string {
	if !strings.EqualFold(strings.TrimSpace(sourceHost), "github.com") {
		return nil
	}
	owner, _, found := strings.Cut(strings.Trim(repository, "/"), "/")
	if !found || owner == "" {
		return nil
	}
	image := (&url.URL{Scheme: "https", Host: "github.com", Path: "/" + owner + ".png", RawQuery: "size=256"}).String()
	return &image
}

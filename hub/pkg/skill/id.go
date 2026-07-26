/*
 * [INPUT]: Depends on public host-qualified Package Paths whose initial source is a Git repository.
 * [OUTPUT]: Provides canonical Package Path parsing and GitHub-backed source validation without member syntax.
 * [POS]: Serves as the public Package identity boundary for Hub source resolution and Catalog indexing.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"fmt"
	"strings"

	protocolpackage "github.com/skillsgo/skillsgo/protocol/packageidentity"
)

type PackagePath = protocolpackage.Path

func ParsePackagePath(value string) (PackagePath, error) {
	return protocolpackage.ParsePath(value)
}

func parseGitHubPackagePath(value string) (PackagePath, error) {
	packagePath, err := ParsePackagePath(value)
	if err != nil {
		return PackagePath{}, err
	}
	parts := strings.Split(packagePath.String(), "/")
	if len(parts) != 3 || parts[0] != "github.com" {
		return PackagePath{}, fmt.Errorf("unsupported Package Path %q", packagePath.String())
	}
	return packagePath, nil
}

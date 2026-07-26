/*
 * [INPUT]: Depends on public host-qualified Module Paths whose initial source is a Git repository.
 * [OUTPUT]: Provides canonical Module Path parsing and GitHub-backed source validation without member syntax.
 * [POS]: Serves as the public Module identity boundary for Hub source resolution and Catalog indexing.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"fmt"
	"strings"

	protocolmodule "github.com/skillsgo/skillsgo/protocol/module"
)

type ModulePath = protocolmodule.Path

func ParseModulePath(value string) (ModulePath, error) {
	return protocolmodule.ParsePath(value)
}

func parseGitHubModulePath(value string) (ModulePath, error) {
	modulePath, err := ParseModulePath(value)
	if err != nil {
		return ModulePath{}, err
	}
	parts := strings.Split(modulePath.String(), "/")
	if len(parts) != 3 || parts[0] != "github.com" {
		return ModulePath{}, fmt.Errorf("unsupported Module Path %q", modulePath.String())
	}
	return modulePath, nil
}

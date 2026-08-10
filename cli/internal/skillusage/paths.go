/*
 * [INPUT]: Depends on caller-provided Agent configuration paths and the current user's resolved home directory.
 * [OUTPUT]: Provides platform-portable configured-home expansion shared by supported-Agent usage adapters.
 * [POS]: Serves as the small path-normalization boundary for the skillusage module.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skillusage

import (
	"path/filepath"
	"strings"
)

func expandConfiguredHome(configured, home string) string {
	configured = strings.TrimSpace(configured)
	if configured == "~" {
		return home
	}
	if strings.HasPrefix(configured, "~/") || strings.HasPrefix(configured, `~\`) {
		return filepath.Join(home, filepath.FromSlash(strings.ReplaceAll(configured[2:], `\`, "/")))
	}
	return configured
}

/*
 * [INPUT]: Depends on public host-qualified Module paths.
 * [OUTPUT]: Provides the canonical Module Path value object, parsing, formatting, and default HTTPS source URLs without Skill-member syntax.
 * [POS]: Serves as the shared public Module identity module beneath Hub source resolution and client coordinates.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package module

import (
	"fmt"
	"strings"
)

type Path struct{ value string }

func ParsePath(value string) (Path, error) {
	if value == "" || value != strings.Trim(value, "/") || strings.ContainsAny(value, "\\?%#\x00") || strings.Contains(value, "://") || containsControl(value) {
		return Path{}, fmt.Errorf("invalid Module Path %q", value)
	}
	value = canonical(strings.TrimSuffix(value, ".git"))
	parts := strings.Split(value, "/")
	if len(parts) < 2 {
		return Path{}, fmt.Errorf("invalid Module Path %q: expected host and path", value)
	}
	host := parts[0]
	if (!strings.Contains(host, ".") && host != "localhost") || strings.Contains(host, "@") {
		return Path{}, fmt.Errorf("invalid Module Path %q: expected a full host name", value)
	}
	if host == "github.com" && len(parts) != 3 {
		return Path{}, fmt.Errorf("invalid GitHub-backed Module Path %q: expected github.com/owner/repo", value)
	}
	for _, segment := range parts {
		if segment == "" || segment == "." || segment == ".." {
			return Path{}, fmt.Errorf("invalid Module Path %q: non-canonical segment %q", value, segment)
		}
	}
	return Path{value: value}, nil
}

func canonical(value string) string {
	host, path, found := strings.Cut(value, "/")
	if !found {
		return strings.ToLower(value)
	}
	host = strings.ToLower(host)
	if host == "github.com" {
		path = strings.ToLower(path)
	}
	return host + "/" + path
}

func containsControl(value string) bool {
	for _, character := range value {
		if character < 0x20 || character == 0x7f {
			return true
		}
	}
	return false
}

func (modulePath Path) String() string    { return modulePath.value }
func (modulePath Path) SourceURL() string { return "https://" + modulePath.value }

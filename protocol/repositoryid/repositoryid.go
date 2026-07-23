/*
 * [INPUT]: Depends on public host-qualified Git Repository coordinates.
 * [OUTPUT]: Provides canonical Repository ID parsing, formatting, and HTTPS source URLs without any Skill-member syntax.
 * [POS]: Serves as the shared public Repository identity contract beneath CLI source aliases and Hub source resolution.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package repositoryid

import (
	"fmt"
	"strings"
)

type ID struct{ Repository string }

func Parse(value string) (ID, error) {
	if value == "" || value != strings.Trim(value, "/") || strings.ContainsAny(value, "\\?%#\x00") || strings.Contains(value, "://") || containsControl(value) {
		return ID{}, fmt.Errorf("invalid Repository ID %q", value)
	}
	value = canonical(strings.TrimSuffix(value, ".git"))
	parts := strings.Split(value, "/")
	if len(parts) < 2 {
		return ID{}, fmt.Errorf("invalid Repository ID %q: expected host and repository path", value)
	}
	host := parts[0]
	if (!strings.Contains(host, ".") && host != "localhost") || strings.Contains(host, "@") {
		return ID{}, fmt.Errorf("invalid Repository ID %q: expected a full host name", value)
	}
	if host == "github.com" && len(parts) != 3 {
		return ID{}, fmt.Errorf("invalid GitHub Repository %q: expected github.com/owner/repo", value)
	}
	for _, segment := range parts {
		if segment == "" || segment == "." || segment == ".." {
			return ID{}, fmt.Errorf("invalid Repository ID %q: non-canonical segment %q", value, segment)
		}
	}
	return ID{Repository: value}, nil
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

func (id ID) String() string        { return id.Repository }
func (id ID) RepositoryURL() string { return "https://" + id.Repository }

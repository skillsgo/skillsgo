/*
 * [INPUT]: Depends on user-supplied add-time Module Version Queries and canonical immutable version recognition.
 * [OUTPUT]: Provides the Go Module Version Query grammar for immutable versions, semantic prefixes/comparisons, latest, and Git revisions.
 * [POS]: Serves as the shared movable-versus-immutable validation boundary for CLI and Hub without performing VCS resolution.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package version

import (
	"fmt"
	"strings"
	"unicode"

	"golang.org/x/mod/semver"
)

type QueryKind string

const (
	QueryImmutable QueryKind = "immutable"
	QueryLatest    QueryKind = "latest"
	QueryPrefix    QueryKind = "prefix"
	QueryCompare   QueryKind = "comparison"
	QueryBranch    QueryKind = "branch"
	QueryCommit    QueryKind = "commit"
)

type Query struct {
	Kind  QueryKind
	Value string
}

func ParseQuery(value string) (Query, error) {
	if value == "" {
		value = "latest"
	}
	if IsImmutable(value) {
		return Query{Kind: QueryImmutable, Value: value}, nil
	}
	if isSemanticPrefix(value) {
		return Query{Kind: QueryPrefix, Value: value}, nil
	}
	if semver.IsValid(value) {
		return Query{}, fmt.Errorf("semantic version Query %q is not canonical", value)
	}
	if len(value) > 1 && value[0] == 'v' && value[1] >= '0' && value[1] <= '9' {
		return Query{}, fmt.Errorf("invalid semantic version Query %q", value)
	}
	switch value {
	case "latest":
		return Query{Kind: QueryLatest, Value: value}, nil
	case "release", "head", "upgrade", "patch", "none":
		return Query{}, fmt.Errorf("Version Query %q is unsupported; use latest, a branch name, or another Go Module Query", value)
	}
	if isSemanticComparison(value) {
		return Query{Kind: QueryCompare, Value: value}, nil
	}
	if isHexRevision(value) {
		return Query{Kind: QueryCommit, Value: strings.ToLower(value)}, nil
	}
	if isAllHex(value) {
		return Query{}, fmt.Errorf("commit Version Query %q must contain 7 to 40 hexadecimal characters", value)
	}
	if err := validateGitBranch(value); err != nil {
		return Query{}, fmt.Errorf("invalid Module Version Query %q: %w", value, err)
	}
	return Query{Kind: QueryBranch, Value: value}, nil
}

func (query Query) Movable() bool { return query.Kind != QueryImmutable }

func isSemanticPrefix(value string) bool {
	if !strings.HasPrefix(value, "v") {
		return false
	}
	parts := strings.Split(strings.TrimPrefix(value, "v"), ".")
	if len(parts) < 1 || len(parts) > 2 {
		return false
	}
	for _, part := range parts {
		if part == "" || (len(part) > 1 && part[0] == '0') {
			return false
		}
		for _, character := range part {
			if character < '0' || character > '9' {
				return false
			}
		}
	}
	return true
}

func isSemanticComparison(value string) bool {
	for _, operator := range []string{"<=", ">=", "<", ">"} {
		if strings.HasPrefix(value, operator) {
			target := strings.TrimPrefix(value, operator)
			return semver.IsValid(target) && semver.Canonical(target) == target
		}
	}
	return false
}

func isHexRevision(value string) bool {
	if len(value) < 7 || len(value) > 40 {
		return false
	}
	for _, character := range value {
		if !((character >= '0' && character <= '9') || (character >= 'a' && character <= 'f') || (character >= 'A' && character <= 'F')) {
			return false
		}
	}
	return true
}

func isAllHex(value string) bool {
	if value == "" {
		return false
	}
	for _, character := range value {
		if !((character >= '0' && character <= '9') || (character >= 'a' && character <= 'f') || (character >= 'A' && character <= 'F')) {
			return false
		}
	}
	return true
}

func validateGitBranch(value string) error {
	if len(value) > 255 || value == "." || value == ".." || strings.HasPrefix(value, "-") ||
		strings.HasPrefix(value, "/") || strings.HasSuffix(value, "/") || strings.HasSuffix(value, ".") ||
		strings.Contains(value, "..") || strings.Contains(value, "//") || strings.Contains(value, "@{") ||
		strings.ContainsAny(value, "\\ ~^:?*[%#<>=!,@") {
		return fmt.Errorf("not a safe Git branch or revision name")
	}
	for _, character := range value {
		if unicode.IsControl(character) || unicode.IsSpace(character) {
			return fmt.Errorf("contains control or whitespace")
		}
	}
	for _, component := range strings.Split(value, "/") {
		if component == "" || component == "." || component == ".." || strings.HasSuffix(component, ".lock") {
			return fmt.Errorf("contains an invalid Git ref component")
		}
	}
	return nil
}

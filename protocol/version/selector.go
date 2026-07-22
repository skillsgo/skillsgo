/*
 * [INPUT]: Depends on user-supplied add-time Repository revision selectors and canonical immutable version recognition.
 * [OUTPUT]: Provides one closed typed Selector grammar for immutable versions, head/release intents, Git branch names, and full/abbreviated commit hashes.
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

type SelectorKind string

const (
	SelectorImmutable SelectorKind = "immutable"
	SelectorHead      SelectorKind = "head"
	SelectorRelease   SelectorKind = "release"
	SelectorBranch    SelectorKind = "branch"
	SelectorCommit    SelectorKind = "commit"
)

type Selector struct {
	Kind  SelectorKind
	Value string
}

func ParseSelector(value string) (Selector, error) {
	if value == "" {
		value = "head"
	}
	if IsImmutable(value) {
		return Selector{Kind: SelectorImmutable, Value: value}, nil
	}
	if semver.IsValid(value) {
		return Selector{}, fmt.Errorf("semantic version Selector %q is not canonical", value)
	}
	switch value {
	case "head":
		return Selector{Kind: SelectorHead, Value: value}, nil
	case "release":
		return Selector{Kind: SelectorRelease, Value: value}, nil
	case "latest":
		return Selector{}, fmt.Errorf("ambiguous Selector %q is unsupported; use head, release, an exact version, branch, or commit", value)
	}
	if isHexRevision(value) {
		return Selector{Kind: SelectorCommit, Value: strings.ToLower(value)}, nil
	}
	if isAllHex(value) {
		return Selector{}, fmt.Errorf("commit Selector %q must contain 7 to 40 hexadecimal characters", value)
	}
	if err := validateGitBranch(value); err != nil {
		return Selector{}, fmt.Errorf("invalid Repository Selector %q: %w", value, err)
	}
	return Selector{Kind: SelectorBranch, Value: value}, nil
}

func (selector Selector) Movable() bool { return selector.Kind != SelectorImmutable }

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

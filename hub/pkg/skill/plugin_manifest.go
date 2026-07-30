/*
 * [INPUT]: Depends on canonical Package paths, selected Skill directories, existing root plugin manifests, and Protocol Artifact entries.
 * [OUTPUT]: Provides deterministic completion of Codex, Claude, and Cursor root plugin manifests without overwriting authored files.
 * [POS]: Serves as the Package Artifact normalization boundary that gives every published Package one stable cross-Agent plugin namespace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"encoding/json"
	"fmt"
	"os"
	"path"
	"sort"
	"strings"
	"unicode"

	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
)

var rootPluginManifestPaths = []string{
	".claude-plugin/plugin.json",
	".codex-plugin/plugin.json",
	".cursor-plugin/plugin.json",
}

type generatedPluginManifest struct {
	Name   string   `json:"name"`
	Skills []string `json:"skills"`
}

func completeRootPluginManifests(entries []protocolartifact.Entry, packagePath string, skillDirectories []string) ([]protocolartifact.Entry, error) {
	existing := make(map[string]struct{}, len(rootPluginManifestPaths))
	namespace := ""
	for _, entry := range entries {
		if !stringSliceContains(rootPluginManifestPaths, entry.Path) {
			continue
		}
		existing[entry.Path] = struct{}{}
		var manifest struct {
			Name string `json:"name"`
		}
		if err := json.Unmarshal(entry.Contents, &manifest); err != nil || strings.TrimSpace(manifest.Name) == "" {
			return nil, fmt.Errorf("root plugin manifest %q must contain valid JSON and a non-empty name", entry.Path)
		}
		name := strings.TrimSpace(manifest.Name)
		if namespace != "" && namespace != name {
			return nil, fmt.Errorf("root plugin manifests disagree on namespace: %q and %q", namespace, name)
		}
		namespace = name
	}
	if namespace == "" {
		namespace = packagePluginNamespace(packagePath)
	}
	if namespace == "" {
		return nil, fmt.Errorf("Package path %q cannot produce a plugin namespace", packagePath)
	}

	skills := make([]string, 0, len(skillDirectories))
	for _, directory := range minimalSkillDirectories(skillDirectories) {
		if directory == "." {
			skills = append(skills, "./")
		} else {
			skills = append(skills, "./"+directory)
		}
	}
	sort.Strings(skills)
	contents, err := json.MarshalIndent(generatedPluginManifest{Name: namespace, Skills: skills}, "", "  ")
	if err != nil {
		return nil, fmt.Errorf("encode generated plugin manifest: %w", err)
	}
	contents = append(contents, '\n')
	for _, manifestPath := range rootPluginManifestPaths {
		if _, found := existing[manifestPath]; found {
			continue
		}
		entries = append(entries, protocolartifact.Entry{Path: manifestPath, Contents: append([]byte(nil), contents...), Mode: os.FileMode(0o644), Size: int64(len(contents))})
	}
	return entries, nil
}

func packagePluginNamespace(packagePath string) string {
	parts := strings.Split(strings.TrimSuffix(path.Clean(packagePath), ".git"), "/")
	if len(parts) > 1 {
		parts = parts[1:]
	}
	var result strings.Builder
	lastHyphen := false
	for _, character := range strings.ToLower(strings.Join(parts, "-")) {
		switch {
		case character >= 'a' && character <= 'z', character >= '0' && character <= '9':
			result.WriteRune(character)
			lastHyphen = false
		case unicode.IsLetter(character), unicode.IsDigit(character), character == '-', character == '_', character == '.':
			if result.Len() > 0 && !lastHyphen {
				result.WriteByte('-')
				lastHyphen = true
			}
		}
	}
	return strings.Trim(result.String(), "-")
}

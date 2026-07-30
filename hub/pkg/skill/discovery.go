/*
 * [INPUT]: Depends on normalized Git tree paths and the directory conventions implemented by the skills.sh CLI.
 * [OUTPUT]: Selects ordered SKILL.md publication candidates using root precedence, conventional containers, bounded catalog depth, and recursive fallback.
 * [POS]: Serves as the pure source-tree discovery policy shared by Git-backed Repository publication.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package skill

import (
	"encoding/json"
	"path"
	"sort"
	"strings"
)

var conventionalSkillContainers = []string{
	"skills",
	"skills/.curated",
	"skills/.experimental",
	"skills/.system",
	".agents/skills",
	".claude/skills",
	".cline/skills",
	".codebuddy/skills",
	".codex/skills",
	".commandcode/skills",
	".continue/skills",
	".github/skills",
	".goose/skills",
	".iflow/skills",
	".junie/skills",
	".kilocode/skills",
	".kiro/skills",
	".mux/skills",
	".neovate/skills",
	".opencode/skills",
	".openhands/skills",
	".pi/skills",
	".qoder/skills",
	".roo/skills",
	".trae/skills",
	".windsurf/skills",
	".zcode/skills",
	".zencoder/skills",
}

var recursiveDiscoverySkippedDirectories = map[string]struct{}{
	"node_modules": {},
	".git":         {},
	"dist":         {},
	"build":        {},
	"__pycache__":  {},
}

type pluginManifestDocuments struct {
	marketplace []byte
	plugin      []byte
}

type skillCandidateTier struct {
	candidates    []string
	shadowParents map[string]string
}

func discoverSkillCandidates(files []string, documents ...pluginManifestDocuments) []string {
	for _, tier := range discoverSkillCandidateTiers(files, documents...) {
		if len(tier.candidates) > 0 {
			return tier.candidates
		}
	}
	return nil
}

func discoverSkillCandidateTiers(files []string, documents ...pluginManifestDocuments) []skillCandidateTier {
	fileSet := make(map[string]struct{}, len(files))
	for _, file := range files {
		if file != "" {
			fileSet[file] = struct{}{}
		}
	}
	tiers := make([]skillCandidateTier, 0, 3)
	if _, ok := fileSet["SKILL.md"]; ok {
		tiers = append(tiers, skillCandidateTier{candidates: []string{"SKILL.md"}})
	}

	selected := make(map[string]struct{})
	shadowParents := make(map[string]string)
	for file := range fileSet {
		parts := strings.Split(file, "/")
		if len(parts) == 2 && parts[1] == "SKILL.md" {
			selected[file] = struct{}{}
		}
	}
	for _, container := range conventionalSkillContainers {
		prefix := container + "/"
		for file := range fileSet {
			if !strings.HasPrefix(file, prefix) {
				continue
			}
			remainder := strings.TrimPrefix(file, prefix)
			parts := strings.Split(remainder, "/")
			switch {
			case len(parts) == 1 && parts[0] == "SKILL.md":
				selected[file] = struct{}{}
			case len(parts) == 2 && parts[1] == "SKILL.md":
				selected[file] = struct{}{}
			case len(parts) == 3 && parts[2] == "SKILL.md":
				if _, skipped := recursiveDiscoverySkippedDirectories[parts[0]]; skipped {
					continue
				}
				if _, skipped := recursiveDiscoverySkippedDirectories[parts[1]]; skipped {
					continue
				}
				selected[file] = struct{}{}
				shadowParents[path.Dir(file)] = path.Join(container, parts[0])
			}
		}
	}
	for _, container := range pluginSkillContainers(documents...) {
		prefix := container
		if prefix != "" {
			prefix += "/"
		}
		for file := range fileSet {
			if !strings.HasPrefix(file, prefix) {
				continue
			}
			parts := strings.Split(strings.TrimPrefix(file, prefix), "/")
			if len(parts) == 2 && parts[1] == "SKILL.md" {
				selected[file] = struct{}{}
			}
		}
	}
	if len(selected) > 0 {
		tiers = append(tiers, skillCandidateTier{candidates: sortedCandidateSet(selected), shadowParents: shadowParents})
	}

	selected = make(map[string]struct{})
	for file := range fileSet {
		if file != "SKILL.md" && !strings.HasSuffix(file, "/SKILL.md") {
			continue
		}
		parts := strings.Split(file, "/")
		if len(parts) > 6 {
			continue
		}
		skipped := false
		for _, part := range parts[:len(parts)-1] {
			if _, exists := recursiveDiscoverySkippedDirectories[part]; exists {
				skipped = true
				break
			}
		}
		if !skipped {
			selected[file] = struct{}{}
		}
	}
	if len(selected) > 0 {
		tiers = append(tiers, skillCandidateTier{candidates: sortedCandidateSet(selected)})
	}
	return tiers
}

func shadowNestedMembers(members []RepositoryMember, shadowParents map[string]string) []RepositoryMember {
	validPaths := make(map[string]struct{}, len(members))
	for _, member := range members {
		validPaths[member.Path] = struct{}{}
	}
	result := make([]RepositoryMember, 0, len(members))
	for _, member := range members {
		parent, canBeShadowed := shadowParents[member.Path]
		if canBeShadowed {
			if _, parentIsValid := validPaths[parent]; parentIsValid {
				continue
			}
		}
		result = append(result, member)
	}
	return result
}

type pluginManifest struct {
	Metadata *struct {
		PluginRoot string `json:"pluginRoot"`
	} `json:"metadata"`
	Plugins []struct {
		Source json.RawMessage `json:"source"`
		Skills []string        `json:"skills"`
	} `json:"plugins"`
	Skills []string `json:"skills"`
}

func pluginSkillContainers(documents ...pluginManifestDocuments) []string {
	containers := make(map[string]struct{})
	add := func(base string, skills []string) {
		if base != "" {
			containers[path.Join(base, "skills")] = struct{}{}
		} else {
			containers["skills"] = struct{}{}
		}
		for _, skillPath := range skills {
			if !strings.HasPrefix(skillPath, "./") {
				continue
			}
			resolved := path.Clean(path.Join(base, skillPath))
			if resolved == "." || resolved == ".." || strings.HasPrefix(resolved, "../") || strings.HasPrefix(resolved, "/") {
				continue
			}
			containers[path.Dir(resolved)] = struct{}{}
		}
	}
	var marketplaceContents, pluginContents []byte
	if len(documents) > 0 {
		marketplaceContents = documents[0].marketplace
		pluginContents = documents[0].plugin
	}
	for _, input := range []struct {
		contents    []byte
		marketplace bool
	}{
		{contents: marketplaceContents, marketplace: true},
		{contents: pluginContents},
	} {
		contents := input.contents
		if len(contents) == 0 {
			continue
		}
		var manifest pluginManifest
		if json.Unmarshal(contents, &manifest) != nil {
			continue
		}
		if !input.marketplace {
			add("", manifest.Skills)
			continue
		}
		pluginRoot := ""
		if manifest.Metadata != nil && manifest.Metadata.PluginRoot != "" {
			if !strings.HasPrefix(manifest.Metadata.PluginRoot, "./") {
				continue
			}
			pluginRoot = path.Clean(manifest.Metadata.PluginRoot)
			if pluginRoot == ".." || strings.HasPrefix(pluginRoot, "../") {
				continue
			}
		}
		for _, plugin := range manifest.Plugins {
			source := ""
			if len(plugin.Source) > 0 && string(plugin.Source) != "null" {
				if json.Unmarshal(plugin.Source, &source) != nil || !strings.HasPrefix(source, "./") {
					continue
				}
			}
			base := path.Clean(path.Join(pluginRoot, source))
			if base == "." {
				base = ""
			}
			if base == ".." || strings.HasPrefix(base, "../") || strings.HasPrefix(base, "/") {
				continue
			}
			add(base, plugin.Skills)
		}
	}
	return sortedCandidateSet(containers)
}

func sortedCandidateSet(candidates map[string]struct{}) []string {
	result := make([]string, 0, len(candidates))
	for candidate := range candidates {
		result = append(result, candidate)
	}
	sort.Strings(result)
	return result
}

func minimalSkillDirectories(directories []string) []string {
	unique := make(map[string]struct{}, len(directories))
	for _, directory := range directories {
		unique[directory] = struct{}{}
	}
	ordered := make([]string, 0, len(unique))
	for directory := range unique {
		ordered = append(ordered, directory)
	}
	sort.Slice(ordered, func(i, j int) bool {
		if len(ordered[i]) != len(ordered[j]) {
			return len(ordered[i]) < len(ordered[j])
		}
		return ordered[i] < ordered[j]
	})
	result := make([]string, 0, len(ordered))
	for _, directory := range ordered {
		covered := false
		for _, parent := range result {
			if parent == "." || strings.HasPrefix(directory, parent+"/") {
				covered = true
				break
			}
		}
		if !covered {
			result = append(result, directory)
		}
	}
	sort.Strings(result)
	return result
}

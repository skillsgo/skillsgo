/*
 * [INPUT]: Depends on discovered External entries plus supported global and Workspace skills.sh lock records containing canonicalizable repository sources.
 * [OUTPUT]: Adds an optional canonical Adoption Package hint when all matching local lock evidence agrees, without changing External ownership or choosing a version.
 * [POS]: Serves as the offline lock-backed candidate restriction pass between External discovery and App-facing inventory serialization.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package inventory

import (
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/source"
)

const skillsShLockReadLimit = 1 << 20

type skillsShLock struct {
	Version int                          `json:"version"`
	Skills  map[string]skillsShLockEntry `json:"skills"`
}

type skillsShLockEntry struct {
	Source     string `json:"source"`
	SourceType string `json:"sourceType"`
	SourceURL  string `json:"sourceUrl"`
}

type skillsShLockLocation struct {
	root            string
	path            string
	expectedVersion int
}

func addExternalAdoptionPackageHints(entries map[string]*Entry, home string) {
	cache := map[skillsShLockLocation]skillsShLock{}
	for _, entry := range entries {
		if entry.Provenance != ProvenanceExternal {
			continue
		}
		packagePaths := map[string]bool{}
		for _, target := range entry.Targets {
			location := skillsShLockForTarget(target, home)
			if location.root == "" {
				continue
			}
			lock, ok := cache[location]
			if !ok {
				lock = readSkillsShLock(location)
				cache[location] = lock
			}
			record, found := lock.Skills[entry.Name]
			if !found {
				record, found = lock.Skills[filepath.Base(target.Path)]
			}
			if !found {
				continue
			}
			if packagePath, valid := skillsShPackagePath(record); valid {
				packagePaths[packagePath] = true
			}
		}
		if len(packagePaths) == 1 {
			for packagePath := range packagePaths {
				entry.AdoptionPackagePath = packagePath
			}
		}
	}
}

func skillsShLockForTarget(target Target, home string) skillsShLockLocation {
	if target.Scope == install.ScopeProject {
		if target.ProjectRoot == "" {
			return skillsShLockLocation{}
		}
		return skillsShLockLocation{root: target.ProjectRoot, path: "skills-lock.json", expectedVersion: 1}
	}
	if stateHome := strings.TrimSpace(os.Getenv("XDG_STATE_HOME")); stateHome != "" {
		return skillsShLockLocation{root: stateHome, path: filepath.FromSlash("skills/.skill-lock.json"), expectedVersion: 3}
	}
	return skillsShLockLocation{root: home, path: filepath.FromSlash(".agents/.skill-lock.json"), expectedVersion: 3}
}

func readSkillsShLock(location skillsShLockLocation) skillsShLock {
	empty := skillsShLock{Skills: map[string]skillsShLockEntry{}}
	root, err := os.OpenRoot(location.root)
	if err != nil {
		return empty
	}
	defer root.Close()
	file, err := root.Open(location.path)
	if err != nil {
		return empty
	}
	defer file.Close()
	info, err := file.Stat()
	if err != nil || !info.Mode().IsRegular() || info.Size() > skillsShLockReadLimit {
		return empty
	}
	decoder := json.NewDecoder(io.LimitReader(file, skillsShLockReadLimit+1))
	var lock skillsShLock
	if decoder.Decode(&lock) != nil || decoder.Decode(&struct{}{}) != io.EOF || lock.Version != location.expectedVersion || lock.Skills == nil {
		return empty
	}
	return lock
}

func skillsShPackagePath(record skillsShLockEntry) (string, bool) {
	var candidates []string
	switch strings.ToLower(strings.TrimSpace(record.SourceType)) {
	case "github":
		candidates = []string{record.Source, record.SourceURL}
	case "git", "gitlab":
		candidates = []string{record.SourceURL}
	default:
		return "", false
	}
	for _, candidate := range candidates {
		reference, err := source.Parse(candidate)
		if err == nil && (strings.ToLower(strings.TrimSpace(record.SourceType)) != "github" || strings.HasPrefix(reference.PackagePath, "github.com/")) {
			return reference.PackagePath, true
		}
	}
	return "", false
}

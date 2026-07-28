/*
 * [INPUT]: Depends on one user home, explicit Workspace directory paths, canonical filesystem resolution, and atomic JSON file replacement.
 * [OUTPUT]: Provides deterministic add, atomic move, remove, and list operations for the user-level Managed Scope registry.
 * [POS]: Serves as the CLI-owned authority for explicitly managed Workspace roots used by cross-Scope commands and the App.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package projectregistry

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

const schemaVersion = 1

type Project struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Root string `json:"root"`
}

type document struct {
	SchemaVersion int       `json:"schemaVersion"`
	Projects      []Project `json:"projects"`
}

type Registry struct{ Home string }

func (r Registry) path() string { return filepath.Join(r.Home, ".skillsgo", "managed-scopes.json") }

func (r Registry) List() ([]Project, error) {
	data, err := os.ReadFile(r.path())
	if errors.Is(err, os.ErrNotExist) {
		return []Project{}, nil
	}
	if err != nil {
		return nil, err
	}
	var stored document
	decoder := json.NewDecoder(strings.NewReader(string(data)))
	decoder.DisallowUnknownFields()
	if decoder.Decode(&stored) != nil || stored.SchemaVersion != schemaVersion {
		return nil, fmt.Errorf("invalid Managed Scope registry")
	}
	seenIDs, seenRoots := map[string]bool{}, map[string]bool{}
	for _, project := range stored.Projects {
		if project.ID == "" || project.Name == "" || !filepath.IsAbs(project.Root) || seenIDs[project.ID] || seenRoots[project.Root] {
			return nil, fmt.Errorf("invalid Managed Scope registry")
		}
		seenIDs[project.ID], seenRoots[project.Root] = true, true
	}
	sort.Slice(stored.Projects, func(i, j int) bool { return stored.Projects[i].Root < stored.Projects[j].Root })
	return stored.Projects, nil
}

func (r Registry) Add(rawRoot string) (Project, error) {
	root, err := canonicalRoot(rawRoot)
	if err != nil {
		return Project{}, err
	}
	projects, err := r.List()
	if err != nil {
		return Project{}, err
	}
	for _, project := range projects {
		if project.Root == root {
			return project, nil
		}
	}
	digest := sha256.Sum256([]byte(root))
	name := filepath.Base(root)
	if name == "." || name == string(filepath.Separator) || name == "" {
		name = root
	}
	project := Project{ID: hex.EncodeToString(digest[:8]), Name: name, Root: root}
	projects = append(projects, project)
	return project, r.write(projects)
}

func (r Registry) Remove(idOrRoot string) (bool, error) {
	projects, err := r.List()
	if err != nil {
		return false, err
	}
	root := strings.TrimSpace(idOrRoot)
	if filepath.IsAbs(root) {
		root = filepath.Clean(root)
	}
	kept := make([]Project, 0, len(projects))
	removed := false
	for _, project := range projects {
		if project.ID == idOrRoot || project.Root == root {
			removed = true
			continue
		}
		kept = append(kept, project)
	}
	if !removed {
		return false, nil
	}
	return true, r.write(kept)
}

func (r Registry) Move(id, rawRoot string) (Project, error) {
	root, err := canonicalRoot(rawRoot)
	if err != nil {
		return Project{}, err
	}
	projects, err := r.List()
	if err != nil {
		return Project{}, err
	}
	index := -1
	for currentIndex, project := range projects {
		if project.ID == id {
			index = currentIndex
		}
		if project.Root == root && project.ID != id {
			return Project{}, fmt.Errorf("Managed Workspace is already registered")
		}
	}
	if index < 0 {
		return Project{}, fmt.Errorf("Managed Workspace not found")
	}
	digest := sha256.Sum256([]byte(root))
	name := filepath.Base(root)
	if name == "." || name == string(filepath.Separator) || name == "" {
		name = root
	}
	moved := Project{ID: hex.EncodeToString(digest[:8]), Name: name, Root: root}
	projects[index] = moved
	return moved, r.write(projects)
}

func canonicalRoot(raw string) (string, error) {
	root, err := filepath.Abs(strings.TrimSpace(raw))
	if err != nil || strings.TrimSpace(raw) == "" {
		return "", fmt.Errorf("invalid Workspace root")
	}
	info, err := os.Stat(root)
	if err != nil {
		return "", err
	}
	if !info.IsDir() {
		return "", fmt.Errorf("Workspace root is not a directory")
	}
	resolved, err := filepath.EvalSymlinks(root)
	if err != nil {
		return "", err
	}
	return filepath.Clean(resolved), nil
}

func (r Registry) write(projects []Project) error {
	sort.Slice(projects, func(i, j int) bool { return projects[i].Root < projects[j].Root })
	encoded, err := json.MarshalIndent(document{SchemaVersion: schemaVersion, Projects: projects}, "", "  ")
	if err != nil {
		return err
	}
	path := r.path()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	temporary, err := os.CreateTemp(filepath.Dir(path), ".managed-scopes-*.tmp")
	if err != nil {
		return err
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)
	if err := temporary.Chmod(0o600); err != nil {
		temporary.Close()
		return err
	}
	if _, err := temporary.Write(append(encoded, '\n')); err != nil {
		temporary.Close()
		return err
	}
	if err := temporary.Sync(); err != nil {
		temporary.Close()
		return err
	}
	if err := temporary.Close(); err != nil {
		return err
	}
	return os.Rename(temporaryPath, path)
}

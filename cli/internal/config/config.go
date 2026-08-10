/*
 * [INPUT]: Depends on one user home, explicit or locally observed Workspace directory paths, canonical filesystem resolution, strict YAML input, and atomic file replacement.
 * [OUTPUT]: Provides deterministic project add, lazy one-time bootstrap gating, remove, and list operations over canonical path entries in the versioned user-level SkillsGo config.yaml document.
 * [POS]: Serves as the CLI-owned authority for shared user configuration, including managed Workspace projects seeded from recent Agent sessions on an empty registry.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package config

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"
)

const schemaVersion = 1

type Project struct {
	Name string `json:"name"`
	Root string `json:"root"`
}

type Document struct {
	SchemaVersion        int      `yaml:"schemaVersion"`
	Projects             []string `yaml:"projects"`
	ProjectsBootstrapped bool     `yaml:"projectsBootstrapped,omitempty"`
}

type Store struct{ Home string }

func (s Store) path() string { return filepath.Join(s.Home, ".skillsgo", "config.yaml") }

func (s Store) ListProjects() ([]Project, error) {
	document, err := s.load()
	if err != nil {
		return nil, err
	}
	projects := make([]Project, 0, len(document.Projects))
	for _, root := range document.Projects {
		projects = append(projects, projectFromRoot(root))
	}
	return projects, nil
}

func (s Store) ProjectBootstrapNeeded() (bool, error) {
	document, err := s.load()
	if err != nil {
		return false, err
	}
	return !document.ProjectsBootstrapped, nil
}

func (s Store) AddProject(rawRoot string) (Project, error) {
	root, err := canonicalRoot(rawRoot)
	if err != nil {
		return Project{}, err
	}
	document, err := s.load()
	if err != nil {
		return Project{}, err
	}
	for _, projectRoot := range document.Projects {
		if projectRoot == root {
			if !document.ProjectsBootstrapped {
				document.ProjectsBootstrapped = true
				if err := s.write(document); err != nil {
					return Project{}, err
				}
			}
			return projectFromRoot(root), nil
		}
	}
	project := projectFromRoot(root)
	document.Projects = append(document.Projects, root)
	document.ProjectsBootstrapped = true
	return project, s.write(document)
}

func (s Store) BootstrapProjects(rawRoots []string) ([]Project, error) {
	document, err := s.load()
	if err != nil {
		return nil, err
	}
	if document.ProjectsBootstrapped {
		return projectsFromRoots(document.Projects), nil
	}
	document.ProjectsBootstrapped = true
	if len(document.Projects) > 0 {
		if err := s.write(document); err != nil {
			return nil, err
		}
		return projectsFromRoots(document.Projects), nil
	}
	seen := map[string]bool{}
	for _, rawRoot := range rawRoots {
		root, canonicalErr := canonicalRoot(rawRoot)
		if canonicalErr != nil || seen[root] {
			continue
		}
		seen[root] = true
		document.Projects = append(document.Projects, root)
	}
	if err := s.write(document); err != nil {
		return nil, err
	}
	return projectsFromRoots(document.Projects), nil
}

func (s Store) RemoveProject(rawRoot string) (bool, error) {
	document, err := s.load()
	if err != nil {
		return false, err
	}
	root := strings.TrimSpace(rawRoot)
	if filepath.IsAbs(root) {
		root = filepath.Clean(root)
	}
	kept := make([]string, 0, len(document.Projects))
	removed := false
	for _, projectRoot := range document.Projects {
		if projectRoot == root {
			removed = true
			continue
		}
		kept = append(kept, projectRoot)
	}
	if !removed {
		return false, nil
	}
	document.Projects = kept
	return true, s.write(document)
}

func (s Store) load() (Document, error) {
	data, err := os.ReadFile(s.path())
	if errors.Is(err, os.ErrNotExist) {
		return Document{SchemaVersion: schemaVersion, Projects: []string{}}, nil
	}
	if err != nil {
		return Document{}, err
	}
	var document Document
	decoder := yaml.NewDecoder(bytes.NewReader(data))
	decoder.KnownFields(true)
	if err := decoder.Decode(&document); err != nil {
		return Document{}, fmt.Errorf("invalid SkillsGo configuration: %w", err)
	}
	var extra any
	if err := decoder.Decode(&extra); !errors.Is(err, io.EOF) {
		return Document{}, fmt.Errorf("invalid SkillsGo configuration: multiple YAML documents")
	}
	if document.SchemaVersion != schemaVersion || document.Projects == nil {
		return Document{}, fmt.Errorf("invalid SkillsGo configuration")
	}
	seenRoots := map[string]bool{}
	for _, root := range document.Projects {
		if !filepath.IsAbs(root) || root != filepath.Clean(root) || seenRoots[root] {
			return Document{}, fmt.Errorf("invalid SkillsGo configuration")
		}
		seenRoots[root] = true
	}
	sortProjects(document.Projects)
	return document, nil
}

func (s Store) write(document Document) error {
	document.SchemaVersion = schemaVersion
	if document.Projects == nil {
		document.Projects = []string{}
	}
	sortProjects(document.Projects)
	var encoded bytes.Buffer
	encoder := yaml.NewEncoder(&encoded)
	encoder.SetIndent(2)
	if err := encoder.Encode(document); err != nil {
		return err
	}
	if err := encoder.Close(); err != nil {
		return err
	}
	path := s.path()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	temporary, err := os.CreateTemp(filepath.Dir(path), ".config-*.tmp")
	if err != nil {
		return err
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)
	if err := temporary.Chmod(0o600); err != nil {
		temporary.Close()
		return err
	}
	if _, err := temporary.Write(encoded.Bytes()); err != nil {
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

func projectFromRoot(root string) Project {
	name := filepath.Base(root)
	if name == "." || name == string(filepath.Separator) || name == "" {
		name = root
	}
	return Project{Name: name, Root: root}
}

func projectsFromRoots(roots []string) []Project {
	projects := make([]Project, 0, len(roots))
	for _, root := range roots {
		projects = append(projects, projectFromRoot(root))
	}
	return projects
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

func sortProjects(projects []string) {
	sort.Strings(projects)
}

/*
 * [INPUT]: Depends on canonical Repository IDs, immutable versions, explicit Skill paths and Agent IDs, valid Repository h1 Sums, strict YAML nodes, and the shared metadata transaction lock.
 * [OUTPUT]: Provides strict skillsgo.yaml/skillsgo.lock parsing, nearest YAML-root discovery, atomic paired loading with crash recovery, exact pair validation, deterministic normalization, and paired publication.
 * [POS]: Serves as the portable Repository dependency intent and integrity boundary for Workspace and User scopes.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package project

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"unicode/utf8"

	protocolartifact "github.com/skillsgo/skillsgo/protocol/artifact"
	protocolskillid "github.com/skillsgo/skillsgo/protocol/skillid"
	protocolversion "github.com/skillsgo/skillsgo/protocol/version"
	"gopkg.in/yaml.v3"
)

const (
	WorkspaceManifestName = "skillsgo.yaml"
	DependencyLockName    = "skillsgo.lock"
)

func UserRoot(home string) string { return filepath.Join(home, ".skillsgo") }

type WorkspaceManifest struct {
	Dependencies map[string]RepositoryDependency `yaml:"dependencies"`
}

type RepositoryDependency struct {
	Version string   `yaml:"version"`
	Skills  []string `yaml:"skills"`
	Agents  []string `yaml:"agents"`
}

type DependencyLock struct {
	Dependencies map[string]LockedRepository `yaml:"dependencies"`
}

type LockedRepository struct {
	Version string `yaml:"version"`
	Sum     string `yaml:"sum"`
}

func LoadWorkspaceManifest(root string) (WorkspaceManifest, error) {
	path := filepath.Join(root, WorkspaceManifestName)
	data, err := os.ReadFile(path)
	if err != nil {
		return WorkspaceManifest{}, err
	}
	return ParseWorkspaceManifest(path, data)
}

func FindWorkspaceRoot(start string) (string, error) {
	current, err := filepath.Abs(start)
	if err != nil {
		return "", err
	}
	for {
		info, statErr := os.Stat(filepath.Join(current, WorkspaceManifestName))
		if statErr == nil {
			if !info.Mode().IsRegular() {
				return "", fmt.Errorf("%s is not a regular file", filepath.Join(current, WorkspaceManifestName))
			}
			return current, nil
		}
		if !os.IsNotExist(statErr) {
			return "", statErr
		}
		parent := filepath.Dir(current)
		if parent == current {
			return "", os.ErrNotExist
		}
		current = parent
	}
}

func ParseWorkspaceManifest(path string, data []byte) (WorkspaceManifest, error) {
	root, err := strictYAMLRoot(path, data, map[string]bool{"dependencies": true})
	if err != nil {
		return WorkspaceManifest{}, err
	}
	dependenciesNode := mappingValue(root, "dependencies")
	if dependenciesNode == nil || dependenciesNode.Kind != yaml.MappingNode {
		return WorkspaceManifest{}, fmt.Errorf("parse %s: dependencies must be a mapping", path)
	}
	if err := rejectDuplicateMappingKeys(path, dependenciesNode); err != nil {
		return WorkspaceManifest{}, err
	}
	manifest := WorkspaceManifest{Dependencies: make(map[string]RepositoryDependency, len(dependenciesNode.Content)/2)}
	for index := 0; index < len(dependenciesNode.Content); index += 2 {
		repositoryID, node := dependenciesNode.Content[index].Value, dependenciesNode.Content[index+1]
		if err := validateRepositoryID(repositoryID); err != nil {
			return WorkspaceManifest{}, fmt.Errorf("parse %s: %w", path, err)
		}
		if err := validateMapping(path, node, map[string]bool{"version": true, "skills": true, "agents": true}); err != nil {
			return WorkspaceManifest{}, err
		}
		if err := validateStringScalar(path, mappingValue(node, "version"), "version"); err != nil {
			return WorkspaceManifest{}, err
		}
		if err := validateStringSequence(path, mappingValue(node, "skills"), "skills"); err != nil {
			return WorkspaceManifest{}, err
		}
		if err := validateStringSequence(path, mappingValue(node, "agents"), "agents"); err != nil {
			return WorkspaceManifest{}, err
		}
		dependency := RepositoryDependency{}
		if err := node.Decode(&dependency); err != nil {
			return WorkspaceManifest{}, fmt.Errorf("parse %s: invalid dependency %q: %w", path, repositoryID, err)
		}
		if err := validateRepositoryDependency(repositoryID, dependency); err != nil {
			return WorkspaceManifest{}, fmt.Errorf("parse %s: %w", path, err)
		}
		manifest.Dependencies[repositoryID] = normalizedDependency(dependency)
	}
	return manifest, nil
}

func LoadDependencyLock(root string) (DependencyLock, error) {
	path := filepath.Join(root, DependencyLockName)
	data, err := os.ReadFile(path)
	if err != nil {
		return DependencyLock{}, err
	}
	return ParseDependencyLock(path, data)
}

// LoadWorkspaceState recovers an interrupted paired publication before exposing
// either file, then returns one atomic YAML/Lock snapshot. found is false only
// when neither declaration exists after recovery.
func LoadWorkspaceState(root string) (manifest WorkspaceManifest, lock DependencyLock, found bool, err error) {
	manifest = WorkspaceManifest{Dependencies: map[string]RepositoryDependency{}}
	lock = DependencyLock{Dependencies: map[string]LockedRepository{}}
	err = withWorkspaceMetadataLock(root, func() error {
		loadedManifest, manifestErr := LoadWorkspaceManifest(root)
		loadedLock, lockErr := LoadDependencyLock(root)
		switch {
		case manifestErr == nil && lockErr == nil:
			manifest, lock, found = loadedManifest, loadedLock, true
			return nil
		case os.IsNotExist(manifestErr) && os.IsNotExist(lockErr):
			return nil
		case manifestErr != nil && !os.IsNotExist(manifestErr):
			return manifestErr
		case lockErr != nil && !os.IsNotExist(lockErr):
			return lockErr
		default:
			return fmt.Errorf("skillsgo.yaml and skillsgo.lock must either both exist or both be absent")
		}
	})
	return manifest, lock, found, err
}

func ParseDependencyLock(path string, data []byte) (DependencyLock, error) {
	root, err := strictYAMLRoot(path, data, map[string]bool{"dependencies": true})
	if err != nil {
		return DependencyLock{}, err
	}
	dependenciesNode := mappingValue(root, "dependencies")
	if dependenciesNode == nil || dependenciesNode.Kind != yaml.MappingNode {
		return DependencyLock{}, fmt.Errorf("parse %s: dependencies must be a mapping", path)
	}
	if err := rejectDuplicateMappingKeys(path, dependenciesNode); err != nil {
		return DependencyLock{}, err
	}
	lock := DependencyLock{Dependencies: make(map[string]LockedRepository, len(dependenciesNode.Content)/2)}
	for index := 0; index < len(dependenciesNode.Content); index += 2 {
		repositoryID, node := dependenciesNode.Content[index].Value, dependenciesNode.Content[index+1]
		if err := validateRepositoryID(repositoryID); err != nil {
			return DependencyLock{}, fmt.Errorf("parse %s: %w", path, err)
		}
		if err := validateMapping(path, node, map[string]bool{"version": true, "sum": true}); err != nil {
			return DependencyLock{}, err
		}
		if err := validateStringScalar(path, mappingValue(node, "version"), "version"); err != nil {
			return DependencyLock{}, err
		}
		if err := validateStringScalar(path, mappingValue(node, "sum"), "sum"); err != nil {
			return DependencyLock{}, err
		}
		var dependency LockedRepository
		if err := node.Decode(&dependency); err != nil {
			return DependencyLock{}, fmt.Errorf("parse %s: invalid lock for %q: %w", path, repositoryID, err)
		}
		if !protocolversion.IsImmutable(dependency.Version) || !protocolartifact.ValidSum(dependency.Sum) {
			return DependencyLock{}, fmt.Errorf("parse %s: lock for %q requires an immutable version and valid h1 Sum", path, repositoryID)
		}
		lock.Dependencies[repositoryID] = dependency
	}
	return lock, nil
}

func WriteWorkspaceState(root string, manifest WorkspaceManifest, lock DependencyLock) error {
	manifest = normalizedManifest(manifest)
	if err := validateWorkspaceState(manifest, lock); err != nil {
		return err
	}
	manifestBytes, err := yaml.Marshal(manifest)
	if err != nil {
		return err
	}
	lockBytes, err := yaml.Marshal(lock)
	if err != nil {
		return err
	}
	if _, err := ParseWorkspaceManifest(WorkspaceManifestName, manifestBytes); err != nil {
		return err
	}
	if _, err := ParseDependencyLock(DependencyLockName, lockBytes); err != nil {
		return err
	}
	return withWorkspaceMetadataLock(root, func() error {
		if err := os.MkdirAll(root, 0o700); err != nil {
			return err
		}
		paths := []string{filepath.Join(root, WorkspaceManifestName), filepath.Join(root, DependencyLockName)}
		snapshots := make([]metadataFileSnapshot, 0, len(paths))
		for _, path := range paths {
			snapshot, err := snapshotMetadataFile(path)
			if err != nil {
				return err
			}
			snapshots = append(snapshots, snapshot)
		}
		journal, err := beginMetadataTransaction(root, snapshots)
		if err != nil {
			return err
		}
		fail := func(cause error) error { return abortMetadataTransaction(journal, snapshots, cause) }
		if err := writeProjectFileAtomic(paths[0], manifestBytes, 0o600); err != nil {
			return fail(err)
		}
		if err := writeProjectFileAtomic(paths[1], lockBytes, 0o600); err != nil {
			return fail(err)
		}
		return os.Remove(journal)
	})
}

func strictYAMLRoot(path string, data []byte, allowed map[string]bool) (*yaml.Node, error) {
	if !utf8.Valid(data) {
		return nil, fmt.Errorf("parse %s: document must be valid UTF-8", path)
	}
	decoder := yaml.NewDecoder(bytes.NewReader(data))
	var document yaml.Node
	if err := decoder.Decode(&document); err != nil {
		return nil, fmt.Errorf("parse %s: %w", path, err)
	}
	if len(document.Content) != 1 || document.Content[0].Kind != yaml.MappingNode {
		return nil, fmt.Errorf("parse %s: document must be a mapping", path)
	}
	var trailing yaml.Node
	if err := decoder.Decode(&trailing); err == nil && len(trailing.Content) > 0 {
		return nil, fmt.Errorf("parse %s: multiple YAML documents are unsupported", path)
	}
	root := document.Content[0]
	if err := rejectYAMLFeatures(path, root); err != nil {
		return nil, err
	}
	if err := validateMapping(path, root, allowed); err != nil {
		return nil, err
	}
	return root, nil
}

func rejectYAMLFeatures(path string, node *yaml.Node) error {
	if node.Kind == yaml.AliasNode || node.Anchor != "" {
		return fmt.Errorf("parse %s line %d: YAML aliases and anchors are unsupported", path, node.Line)
	}
	for _, child := range node.Content {
		if err := rejectYAMLFeatures(path, child); err != nil {
			return err
		}
	}
	return nil
}

func validateStringScalar(path string, node *yaml.Node, field string) error {
	if node == nil || node.Kind != yaml.ScalarNode || node.Tag != "!!str" || node.Value == "" {
		return fmt.Errorf("parse %s: field %q must be a non-empty string", path, field)
	}
	return nil
}

func validateStringSequence(path string, node *yaml.Node, field string) error {
	if node == nil || node.Kind != yaml.SequenceNode {
		return fmt.Errorf("parse %s: field %q must be a string list", path, field)
	}
	for _, item := range node.Content {
		if item.Kind != yaml.ScalarNode || item.Tag != "!!str" || item.Value == "" {
			return fmt.Errorf("parse %s line %d: field %q must contain only non-empty strings", path, item.Line, field)
		}
	}
	return nil
}

func validateMapping(path string, node *yaml.Node, allowed map[string]bool) error {
	if node.Kind != yaml.MappingNode {
		return fmt.Errorf("parse %s line %d: expected a mapping", path, node.Line)
	}
	if err := rejectDuplicateMappingKeys(path, node); err != nil {
		return err
	}
	for index := 0; index < len(node.Content); index += 2 {
		key := node.Content[index]
		if key.Kind != yaml.ScalarNode || key.Tag != "!!str" || !allowed[key.Value] {
			return fmt.Errorf("parse %s line %d: unknown field %q", path, key.Line, key.Value)
		}
	}
	for required := range allowed {
		if mappingValue(node, required) == nil {
			return fmt.Errorf("parse %s: missing required field %q", path, required)
		}
	}
	return nil
}

func rejectDuplicateMappingKeys(path string, node *yaml.Node) error {
	seen := map[string]bool{}
	for index := 0; index < len(node.Content); index += 2 {
		key := node.Content[index]
		if seen[key.Value] {
			return fmt.Errorf("parse %s line %d: duplicate key %q", path, key.Line, key.Value)
		}
		seen[key.Value] = true
	}
	return nil
}

func mappingValue(node *yaml.Node, field string) *yaml.Node {
	for index := 0; index < len(node.Content); index += 2 {
		if node.Content[index].Value == field {
			return node.Content[index+1]
		}
	}
	return nil
}

func validateRepositoryID(repositoryID string) error {
	parsed, err := protocolskillid.Parse(repositoryID)
	if err != nil || parsed.String() != repositoryID || parsed.SkillPath != "." {
		return fmt.Errorf("invalid canonical Repository ID %q", repositoryID)
	}
	return nil
}

func validateRepositoryDependency(repositoryID string, dependency RepositoryDependency) error {
	if !protocolversion.IsImmutable(dependency.Version) {
		return fmt.Errorf("dependency %q requires an immutable version", repositoryID)
	}
	if len(dependency.Skills) == 0 || len(dependency.Agents) == 0 {
		return fmt.Errorf("dependency %q requires non-empty skills and agents", repositoryID)
	}
	seenSkills := map[string]bool{}
	for _, member := range dependency.Skills {
		key := "."
		if member != "." {
			portable, err := protocolartifact.PortablePathKey(member)
			if err != nil || strings.HasSuffix(member, "/") {
				return fmt.Errorf("dependency %q contains invalid Skill path %q", repositoryID, member)
			}
			key = portable
		}
		if seenSkills[key] {
			return fmt.Errorf("dependency %q contains duplicate Skill path %q", repositoryID, member)
		}
		seenSkills[key] = true
	}
	seenAgents := map[string]bool{}
	for _, agentID := range dependency.Agents {
		if agentID == "" || strings.TrimSpace(agentID) != agentID || strings.ContainsAny(agentID, " /\\\t\r\n") || seenAgents[agentID] {
			return fmt.Errorf("dependency %q contains invalid or duplicate Agent %q", repositoryID, agentID)
		}
		seenAgents[agentID] = true
	}
	return nil
}

func normalizedDependency(dependency RepositoryDependency) RepositoryDependency {
	dependency.Skills = append([]string(nil), dependency.Skills...)
	dependency.Agents = append([]string(nil), dependency.Agents...)
	sort.Strings(dependency.Skills)
	sort.Strings(dependency.Agents)
	return dependency
}

func normalizedManifest(manifest WorkspaceManifest) WorkspaceManifest {
	normalized := WorkspaceManifest{Dependencies: make(map[string]RepositoryDependency, len(manifest.Dependencies))}
	for repositoryID, dependency := range manifest.Dependencies {
		normalized.Dependencies[repositoryID] = normalizedDependency(dependency)
	}
	return normalized
}

func validateWorkspaceState(manifest WorkspaceManifest, lock DependencyLock) error {
	if len(manifest.Dependencies) != len(lock.Dependencies) {
		return fmt.Errorf("Workspace Manifest and Dependency Lock must contain the same Repositories")
	}
	for repositoryID, dependency := range manifest.Dependencies {
		if err := validateRepositoryID(repositoryID); err != nil {
			return err
		}
		if err := validateRepositoryDependency(repositoryID, dependency); err != nil {
			return err
		}
		locked, ok := lock.Dependencies[repositoryID]
		if !ok || locked.Version != dependency.Version || !protocolartifact.ValidSum(locked.Sum) {
			return fmt.Errorf("Dependency Lock does not authenticate %s@%s", repositoryID, dependency.Version)
		}
	}
	return nil
}

func ValidateWorkspaceState(manifest WorkspaceManifest, lock DependencyLock) error {
	return validateWorkspaceState(manifest, lock)
}

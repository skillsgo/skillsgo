/*
 * [INPUT]: Depends on canonical immutable dependency coordinates, resolved versions, desired Agent IDs, installation modes, and YAML persistence.
 * [OUTPUT]: Provides the editable Workspace Manifest, nearest-root discovery, and atomic requirement replacement or Agent-binding removal.
 * [POS]: Serves as the sole portable desired-state boundary for project and user scopes; resolution integrity belongs to skillsgo.sum.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package project

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"gopkg.in/yaml.v3"
)

const APIVersion = "skillsgo.dev/v1alpha1"

const manifestLockName = ".skillsgo.yaml.lock"

func UserRoot(home string) string { return filepath.Join(home, ".skillsgo") }

type Manifest struct {
	APIVersion string                      `yaml:"apiVersion"`
	Skills     map[string]SkillRequirement `yaml:"dependencies"`
}

type SkillRequirement struct {
	Source string       `yaml:"-"`
	Ref    string       `yaml:"-"`
	Agents []string     `yaml:"-"`
	Mode   install.Mode `yaml:"-"`
}

func (requirement SkillRequirement) MarshalYAML() (any, error) {
	version := strings.TrimSpace(requirement.Ref)
	if version == "" {
		return nil, fmt.Errorf("dependency version must not be empty")
	}
	if len(requirement.Agents) == 0 {
		return version, nil
	}
	return version + " [" + strings.Join(requirement.Agents, ", ") + "]", nil
}

func (requirement *SkillRequirement) UnmarshalYAML(node *yaml.Node) error {
	if node.Kind != yaml.ScalarNode {
		return fmt.Errorf("dependency must be a one-line version and optional Agent list")
	}
	value := strings.TrimSpace(node.Value)
	if value == "" {
		return fmt.Errorf("dependency version must not be empty")
	}
	requirement.Agents = nil
	if strings.HasSuffix(value, "]") {
		opening := strings.LastIndex(value, " [")
		if opening < 0 {
			return fmt.Errorf("invalid Agent list in dependency %q", value)
		}
		rawAgents := strings.TrimSpace(value[opening+2 : len(value)-1])
		if rawAgents == "" {
			return fmt.Errorf("dependency Agent list must not be empty")
		}
		seen := map[string]bool{}
		for _, raw := range strings.Split(rawAgents, ",") {
			agentID := strings.TrimSpace(raw)
			if agentID == "" || strings.ContainsAny(agentID, " []") {
				return fmt.Errorf("invalid Agent %q", raw)
			}
			if !seen[agentID] {
				seen[agentID] = true
				requirement.Agents = append(requirement.Agents, agentID)
			}
		}
		value = strings.TrimSpace(value[:opening])
	}
	if value == "" {
		return fmt.Errorf("dependency version must not be empty")
	}
	requirement.Ref = value
	return nil
}

func FindRoot(start string) (string, error) {
	current, err := filepath.Abs(start)
	if err != nil {
		return "", err
	}
	for {
		manifestErr := fileExists(filepath.Join(current, "skillsgo.yaml"))
		if manifestErr == nil {
			return current, nil
		}
		if !os.IsNotExist(manifestErr) {
			return "", manifestErr
		}
		parent := filepath.Dir(current)
		if parent == current {
			return "", os.ErrNotExist
		}
		current = parent
	}
}

func fileExists(path string) error {
	info, err := os.Stat(path)
	if err != nil {
		return err
	}
	if !info.Mode().IsRegular() {
		return fmt.Errorf("%s is not a regular file", path)
	}
	return nil
}

func (manifest Manifest) Dependency(skillID string) (string, SkillRequirement, bool) {
	requirement, ok := manifest.Skills[skillID]
	return skillID, requirement, ok
}

func LoadManifest(root string) (Manifest, error) {
	var manifest Manifest
	if err := readRequiredYAML(filepath.Join(root, "skillsgo.yaml"), &manifest); err != nil {
		return Manifest{}, err
	}
	if manifest.APIVersion != APIVersion {
		return Manifest{}, fmt.Errorf("unsupported skillsgo.yaml apiVersion %q", manifest.APIVersion)
	}
	if manifest.Skills == nil {
		manifest.Skills = map[string]SkillRequirement{}
	}
	for source, requirement := range manifest.Skills {
		requirement.Source = source
		manifest.Skills[source] = requirement
	}
	return manifest, nil
}

func UpsertManifestRequirement(root, dependency string, requirement SkillRequirement, mergeAgents bool) error {
	if strings.TrimSpace(dependency) == "" || strings.TrimSpace(requirement.Ref) == "" {
		return fmt.Errorf("canonical dependency and resolved version are required")
	}
	if err := os.MkdirAll(root, 0o700); err != nil {
		return err
	}
	unlock, err := acquireFileLock(filepath.Join(root, manifestLockName))
	if err != nil {
		return err
	}
	defer unlock()
	return upsertManifestRequirementLocked(root, dependency, requirement, mergeAgents)
}

func ReplaceManifestBindings(root, dependency string, requirement SkillRequirement, mergeAgents bool, removed []install.Installation) error {
	if strings.TrimSpace(dependency) == "" || strings.TrimSpace(requirement.Ref) == "" {
		return fmt.Errorf("canonical dependency and resolved version are required")
	}
	if err := os.MkdirAll(root, 0o700); err != nil {
		return err
	}
	unlock, err := acquireFileLock(filepath.Join(root, manifestLockName))
	if err != nil {
		return err
	}
	defer unlock()
	manifestPath := filepath.Join(root, "skillsgo.yaml")
	manifest := Manifest{APIVersion: APIVersion, Skills: map[string]SkillRequirement{}}
	if err := readYAMLIfExists(manifestPath, &manifest); err != nil {
		return err
	}
	if manifest.APIVersion != APIVersion {
		return fmt.Errorf("unsupported skillsgo.yaml apiVersion %q", manifest.APIVersion)
	}
	if manifest.Skills == nil {
		manifest.Skills = map[string]SkillRequirement{}
	}
	if existing, ok := manifest.Skills[dependency]; ok && mergeAgents {
		requirement.Agents = mergeAgentIDs(existing.Agents, requirement.Agents)
	}
	requirement.Source = dependency
	manifest.Skills[dependency] = requirement
	removeBindingsFromManifest(&manifest, removed)
	return writeYAMLAtomic(manifestPath, manifest)
}

func upsertManifestRequirementLocked(root, dependency string, requirement SkillRequirement, mergeAgents bool) error {
	manifestPath := filepath.Join(root, "skillsgo.yaml")
	manifest := Manifest{APIVersion: APIVersion, Skills: map[string]SkillRequirement{}}
	if err := readYAMLIfExists(manifestPath, &manifest); err != nil {
		return err
	}
	if manifest.APIVersion != APIVersion {
		return fmt.Errorf("unsupported skillsgo.yaml apiVersion %q", manifest.APIVersion)
	}
	if manifest.Skills == nil {
		manifest.Skills = map[string]SkillRequirement{}
	}
	if existing, ok := manifest.Skills[dependency]; ok && mergeAgents {
		requirement.Agents = mergeAgentIDs(existing.Agents, requirement.Agents)
	}
	requirement.Source = dependency
	manifest.Skills[dependency] = requirement
	return writeYAMLAtomic(manifestPath, manifest)
}

func mergeAgentIDs(existing, added []string) []string {
	seen := map[string]bool{}
	merged := make([]string, 0, len(existing)+len(added))
	for _, agentID := range append(existing, added...) {
		if !seen[agentID] {
			seen[agentID] = true
			merged = append(merged, agentID)
		}
	}
	return merged
}

// Upsert and Replace are execution helpers. Store receipts provide the exact
// identity and version; only canonical desired state is persisted.
func Upsert(root, _ string, requirement SkillRequirement, receipt store.Receipt) error {
	return persistReceiptRequirement(root, requirement, receipt, true)
}

func Replace(root, _ string, requirement SkillRequirement, receipt store.Receipt) error {
	return persistReceiptRequirement(root, requirement, receipt, false)
}

func persistReceiptRequirement(root string, requirement SkillRequirement, receipt store.Receipt, mergeAgents bool) error {
	if receipt.SkillID == "" || receipt.Version == "" {
		return fmt.Errorf("immutable Store receipt identity is required")
	}
	requirement.Source = receipt.SkillID
	requirement.Ref = receipt.Version
	return UpsertManifestRequirement(root, receipt.SkillID, requirement, mergeAgents)
}

func RemoveBindings(root string, removed []install.Installation) error {
	unlock, err := acquireFileLock(filepath.Join(root, manifestLockName))
	if err != nil {
		return err
	}
	defer unlock()
	manifest, err := LoadManifest(root)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	removeBindingsFromManifest(&manifest, removed)
	return writeYAMLAtomic(filepath.Join(root, "skillsgo.yaml"), manifest)
}

func removeBindingsFromManifest(manifest *Manifest, removed []install.Installation) {
	for _, installation := range removed {
		requirement, ok := manifest.Skills[installation.SkillID]
		if !ok {
			continue
		}
		remaining := make([]string, 0, len(requirement.Agents))
		for _, agentID := range requirement.Agents {
			if agentID != installation.Target.Agent {
				remaining = append(remaining, agentID)
			}
		}
		if len(remaining) == 0 {
			delete(manifest.Skills, installation.SkillID)
		} else {
			requirement.Agents = remaining
			manifest.Skills[installation.SkillID] = requirement
		}
	}
}

func RemoveManifestRequirements(root string, dependencies []string) error {
	unlock, err := acquireFileLock(filepath.Join(root, manifestLockName))
	if err != nil {
		return err
	}
	defer unlock()
	manifest, err := LoadManifest(root)
	if err != nil {
		return err
	}
	for _, dependency := range dependencies {
		delete(manifest.Skills, dependency)
	}
	return writeYAMLAtomic(filepath.Join(root, "skillsgo.yaml"), manifest)
}

func readRequiredYAML(path string, target any) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	if err := yaml.Unmarshal(data, target); err != nil {
		return fmt.Errorf("parse %s: %w", path, err)
	}
	return nil
}

func readYAMLIfExists(path string, target any) error {
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	if err := yaml.Unmarshal(data, target); err != nil {
		return fmt.Errorf("parse %s: %w", path, err)
	}
	return nil
}

func writeYAMLAtomic(path string, value any) error {
	data, err := yaml.Marshal(value)
	if err != nil {
		return err
	}
	temporary, err := os.CreateTemp(filepath.Dir(path), ".skillsgo-yaml-")
	if err != nil {
		return err
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)
	if err := temporary.Chmod(0o600); err != nil {
		_ = temporary.Close()
		return err
	}
	if _, err := temporary.Write(data); err != nil {
		_ = temporary.Close()
		return err
	}
	if err := temporary.Sync(); err != nil {
		_ = temporary.Close()
		return err
	}
	if err := temporary.Close(); err != nil {
		return err
	}
	return os.Rename(temporaryPath, path)
}

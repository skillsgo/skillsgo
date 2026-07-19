/*
 * [INPUT]: Depends on canonical immutable dependency coordinates, resolved versions, desired Agent IDs, exact Installation Receipts, and Go module-file syntax validation.
 * [OUTPUT]: Provides the editable skillsgo.mod declaration, nearest-root discovery, shared-lock requirement replacement, and crash-recoverable receipt-aware Agent-binding removal.
 * [POS]: Serves as the sole portable desired-state boundary for project and user scopes; resolution integrity belongs to skillsgo.sum.
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

	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"golang.org/x/mod/modfile"
)

const manifestName = "skillsgo.mod"
const manifestLockName = ".skillsgo.mod.lock"

func UserRoot(home string) string { return filepath.Join(home, ".skillsgo") }

type Manifest struct {
	Skills map[string]SkillRequirement
}

type SkillRequirement struct {
	Source string
	Ref    string
	Agents []string
	Mode   install.Mode
}

func FindRoot(start string) (string, error) {
	current, err := filepath.Abs(start)
	if err != nil {
		return "", err
	}
	for {
		manifestErr := fileExists(filepath.Join(current, manifestName))
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
	path := filepath.Join(root, manifestName)
	data, err := os.ReadFile(path)
	if err != nil {
		return Manifest{}, err
	}
	return parseManifest(path, data)
}

func parseManifest(path string, data []byte) (Manifest, error) {
	converted, versionsBySource, agentsBySource, err := convertAgentListsToComments(data)
	if err != nil {
		return Manifest{}, fmt.Errorf("parse %s: %w", path, err)
	}
	parsed, err := modfile.Parse(path, converted, nil)
	if err != nil {
		return Manifest{}, err
	}
	if parsed.Module != nil || parsed.Go != nil || parsed.Toolchain != nil || len(parsed.Godebug)+len(parsed.Exclude)+len(parsed.Replace)+len(parsed.Retract)+len(parsed.Tool)+len(parsed.Ignore) > 0 {
		return Manifest{}, fmt.Errorf("parse %s: skillsgo.mod supports only require directives", path)
	}
	manifest := Manifest{Skills: map[string]SkillRequirement{}}
	for _, required := range parsed.Require {
		if required.Indirect {
			return Manifest{}, fmt.Errorf("parse %s: indirect requirements are not supported", path)
		}
		if _, exists := manifest.Skills[required.Mod.Path]; exists {
			return Manifest{}, fmt.Errorf("parse %s: duplicate requirement %q", path, required.Mod.Path)
		}
		manifest.Skills[required.Mod.Path] = SkillRequirement{
			Source: required.Mod.Path,
			Ref:    versionsBySource[required.Mod.Path],
			Agents: agentsBySource[required.Mod.Path],
		}
	}
	return manifest, nil
}

// convertAgentListsToComments keeps parsing aligned with Go's module-file
// grammar while treating [agent, ...] as a SkillsGo-specific require suffix.
func convertAgentListsToComments(data []byte) ([]byte, map[string]string, map[string][]string, error) {
	lines := bytes.Split(data, []byte("\n"))
	versionsBySource := map[string]string{}
	agentsBySource := map[string][]string{}
	inRequireBlock := false
	for index, raw := range lines {
		line := string(raw)
		code := strings.TrimSpace(strings.SplitN(line, "//", 2)[0])
		if code == "require (" {
			inRequireBlock = true
			continue
		}
		if inRequireBlock && code == ")" {
			inRequireBlock = false
			continue
		}
		if code == "" || strings.HasPrefix(code, "//") {
			continue
		}
		body := code
		if !inRequireBlock {
			if !strings.HasPrefix(body, "require ") {
				continue
			}
			body = strings.TrimSpace(strings.TrimPrefix(body, "require "))
		}
		opening := strings.LastIndex(body, "[")
		requirementBody := body
		var agents []string
		if opening >= 0 {
			if !strings.HasSuffix(body, "]") {
				return nil, nil, nil, fmt.Errorf("line %d: invalid Agent list", index+1)
			}
			requirementBody = strings.TrimSpace(body[:opening])
			var err error
			agents, err = parseAgents(body[opening+1 : len(body)-1])
			if err != nil {
				return nil, nil, nil, fmt.Errorf("line %d: %w", index+1, err)
			}
		}
		fields := strings.Fields(requirementBody)
		if len(fields) != 2 {
			return nil, nil, nil, fmt.Errorf("line %d: require must contain a coordinate, version, and Agent list", index+1)
		}
		if _, exists := agentsBySource[fields[0]]; exists {
			return nil, nil, nil, fmt.Errorf("line %d: duplicate requirement %q", index+1, fields[0])
		}
		versionsBySource[fields[0]] = fields[1]
		agentsBySource[fields[0]] = agents
		prefix := line[:strings.Index(line, strings.TrimSpace(line))]
		if inRequireBlock {
			lines[index] = []byte(prefix + fields[0] + " v0.0.0")
		} else {
			lines[index] = []byte(prefix + "require " + fields[0] + " v0.0.0")
		}
	}
	return bytes.Join(lines, []byte("\n")), versionsBySource, agentsBySource, nil
}

func parseAgents(raw string) ([]string, error) {
	if strings.TrimSpace(raw) == "" {
		return nil, fmt.Errorf("dependency Agent list must not be empty")
	}
	seen := map[string]bool{}
	agents := make([]string, 0)
	for _, item := range strings.Split(raw, ",") {
		agentID := strings.TrimSpace(item)
		if agentID == "" || strings.ContainsAny(agentID, " []\t\r\n") {
			return nil, fmt.Errorf("invalid Agent %q", item)
		}
		if !seen[agentID] {
			seen[agentID] = true
			agents = append(agents, agentID)
		}
	}
	return agents, nil
}

func UpsertManifestRequirement(root, dependency string, requirement SkillRequirement, mergeAgents bool) error {
	return mutateManifest(root, upsertManifestMutation(dependency, requirement, mergeAgents))
}

func upsertManifestMutation(dependency string, requirement SkillRequirement, mergeAgents bool) func(*Manifest) {
	return func(manifest *Manifest) {
		if existing, ok := manifest.Skills[dependency]; ok && mergeAgents {
			requirement.Agents = mergeAgentIDs(existing.Agents, requirement.Agents)
		}
		requirement.Source = dependency
		manifest.Skills[dependency] = requirement
	}
}

func ReplaceManifestBindings(root, dependency string, requirement SkillRequirement, mergeAgents bool, removed []install.Installation) error {
	return mutateManifest(root, replaceManifestBindingsMutation(dependency, requirement, mergeAgents, removed))
}

func replaceManifestBindingsUnlocked(root, dependency string, requirement SkillRequirement, mergeAgents bool, removed []install.Installation) error {
	return mutateManifestUnlocked(root, replaceManifestBindingsMutation(dependency, requirement, mergeAgents, removed))
}

func replaceManifestBindingsMutation(dependency string, requirement SkillRequirement, mergeAgents bool, removed []install.Installation) func(*Manifest) {
	return func(manifest *Manifest) {
		if existing, ok := manifest.Skills[dependency]; ok && mergeAgents {
			requirement.Agents = mergeAgentIDs(existing.Agents, requirement.Agents)
		}
		requirement.Source = dependency
		manifest.Skills[dependency] = requirement
		removeBindingsFromManifest(manifest, removed)
	}
}

func mutateManifest(root string, mutation func(*Manifest)) error {
	return withInstallationMetadataLock(root, func() error {
		return mutateManifestUnlocked(root, mutation)
	})
}

func mutateManifestUnlocked(root string, mutation func(*Manifest)) error {
	if err := os.MkdirAll(root, 0o700); err != nil {
		return err
	}
	unlock, err := acquireFileLock(filepath.Join(root, manifestLockName))
	if err != nil {
		return err
	}
	defer unlock()
	manifest := Manifest{Skills: map[string]SkillRequirement{}}
	if data, readErr := os.ReadFile(filepath.Join(root, manifestName)); readErr == nil {
		manifest, err = parseManifest(filepath.Join(root, manifestName), data)
		if err != nil {
			return err
		}
	} else if !os.IsNotExist(readErr) {
		return readErr
	}
	mutation(&manifest)
	return writeManifestAtomic(filepath.Join(root, manifestName), manifest)
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

func Upsert(root, _ string, requirement SkillRequirement, receipt store.Receipt) error {
	return persistReceiptRequirement(root, requirement, receipt, true)
}

func Replace(root, _ string, requirement SkillRequirement, receipt store.Receipt) error {
	return persistReceiptRequirement(root, requirement, receipt, false)
}

func persistReceiptRequirement(root string, requirement SkillRequirement, receipt store.Receipt, mergeAgents bool) error {
	return withInstallationMetadataLock(root, func() error {
		return persistReceiptRequirementUnlocked(root, requirement, receipt, mergeAgents)
	})
}

func persistReceiptRequirementUnlocked(root string, requirement SkillRequirement, receipt store.Receipt, mergeAgents bool) error {
	if receipt.SkillID == "" || receipt.Version == "" {
		return fmt.Errorf("immutable Store receipt identity is required")
	}
	requirement.Source = receipt.SkillID
	requirement.Ref = receipt.Version
	return mutateManifestUnlocked(root, upsertManifestMutation(receipt.SkillID, requirement, mergeAgents))
}

func RemoveBindings(root string, removed []install.Installation) error {
	if len(removed) == 0 {
		return nil
	}
	return withInstallationMetadataLock(root, func() error {
		receipts, err := loadInstallationReceiptsUnlocked(root)
		if err != nil {
			return err
		}
		removedReceipt := map[string]bool{}
		for _, installation := range removed {
			removedReceipt[installation.Target.Agent+"\x00"+filepath.Clean(installation.Target.Path)] = true
		}
		manifestRemoved := make([]install.Installation, 0, len(removed))
		for _, installation := range removed {
			dependency := installation.DependencyID
			if dependency == "" {
				dependency = installation.SkillID
			}
			bindingStillPresent := false
			for _, receipt := range receipts {
				key := receipt.Agent + "\x00" + filepath.Clean(receipt.Path)
				if !removedReceipt[key] && receipt.ArtifactSkillID == dependency && receipt.Agent == installation.Target.Agent {
					bindingStillPresent = true
					break
				}
			}
			if !bindingStillPresent {
				manifestRemoved = append(manifestRemoved, installation)
			}
		}
		snapshots, err := receiptSnapshotsForRemoved(root, receipts, removed)
		if err != nil {
			return err
		}
		if _, err := os.Stat(filepath.Join(root, manifestName)); err == nil {
			manifestSnapshot, snapshotErr := snapshotMetadataFile(filepath.Join(root, manifestName))
			if snapshotErr != nil {
				return snapshotErr
			}
			snapshots = append(snapshots, manifestSnapshot)
		} else if !os.IsNotExist(err) {
			return err
		}
		if len(snapshots) == 0 {
			return nil
		}
		journal, err := beginMetadataTransaction(root, snapshots)
		if err != nil {
			return err
		}
		fail := func(cause error) error { return abortMetadataTransaction(journal, snapshots, cause) }
		if _, err := os.Stat(filepath.Join(root, manifestName)); err == nil {
			if err := mutateManifestUnlocked(root, func(manifest *Manifest) { removeBindingsFromManifest(manifest, manifestRemoved) }); err != nil {
				return fail(err)
			}
		}
		if err := removeInstallationReceiptsUnlocked(root, removed); err != nil {
			return fail(err)
		}
		return os.Remove(journal)
	})
}

func removeBindingsFromManifest(manifest *Manifest, removed []install.Installation) {
	for _, installation := range removed {
		dependency := installation.DependencyID
		if dependency == "" {
			dependency = installation.SkillID
		}
		requirement, ok := manifest.Skills[dependency]
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
			delete(manifest.Skills, dependency)
		} else {
			requirement.Agents = remaining
			manifest.Skills[dependency] = requirement
		}
	}
}

func RemoveManifestRequirements(root string, dependencies []string) error {
	return mutateManifest(root, func(manifest *Manifest) {
		for _, dependency := range dependencies {
			delete(manifest.Skills, dependency)
		}
	})
}

func writeManifestAtomic(path string, manifest Manifest) error {
	dependencies := make([]string, 0, len(manifest.Skills))
	for dependency := range manifest.Skills {
		dependencies = append(dependencies, dependency)
	}
	sort.Strings(dependencies)
	var data strings.Builder
	data.WriteString("require (\n")
	for _, dependency := range dependencies {
		requirement := manifest.Skills[dependency]
		if strings.TrimSpace(requirement.Ref) == "" {
			return fmt.Errorf("dependency version must not be empty")
		}
		data.WriteString("\t")
		data.WriteString(dependency)
		data.WriteString(" ")
		data.WriteString(requirement.Ref)
		if len(requirement.Agents) > 0 {
			data.WriteString(" [")
			data.WriteString(strings.Join(requirement.Agents, ", "))
			data.WriteString("]")
		}
		data.WriteString("\n")
	}
	data.WriteString(")\n")
	if _, _, _, err := convertAgentListsToComments([]byte(data.String())); err != nil {
		return err
	}
	temporary, err := os.CreateTemp(filepath.Dir(path), ".skillsgo-mod-")
	if err != nil {
		return err
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)
	if err := temporary.Chmod(0o600); err != nil {
		_ = temporary.Close()
		return err
	}
	if _, err := temporary.WriteString(data.String()); err != nil {
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

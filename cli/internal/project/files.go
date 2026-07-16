/*
 * [INPUT]: Depends on the project package imports and contracts declared in this file.
 * [OUTPUT]: Provides the project package behavior implemented by files.go.
 * [POS]: Serves as maintained source in the project package in its renamed SkillsGo Hub or CLI workspace.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package project

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/install"
	"github.com/skillsgo/skillsgo/cli/internal/store"
	"gopkg.in/yaml.v3"
)

const APIVersion = "skillsgo.dev/v1alpha1"

type Manifest struct {
	APIVersion string                      `yaml:"apiVersion"`
	Skills     map[string]SkillRequirement `yaml:"skills"`
}

type SkillRequirement struct {
	Source string       `yaml:"source"`
	Ref    string       `yaml:"ref,omitempty"`
	Agents []string     `yaml:"agents"`
	Mode   install.Mode `yaml:"mode,omitempty"`
}

func UpdateLock(root, name string, receipt store.Receipt) error {
	lockPath := filepath.Join(root, "skillsgo-lock.yaml")
	var lockfile Lockfile
	if err := readRequiredYAML(lockPath, &lockfile); err != nil {
		return err
	}
	if lockfile.LockfileVersion != 1 {
		return fmt.Errorf("不支持的 skillsgo-lock.yaml lockfileVersion %d", lockfile.LockfileVersion)
	}
	if _, ok := lockfile.Skills[name]; !ok {
		return fmt.Errorf("skillsgo-lock.yaml 缺少 Skill %q", name)
	}
	lockfile.Skills[name] = LockedSkill{SkillID: receipt.SkillID, Version: receipt.Version, SHA256: receipt.SHA256, Origin: receipt.Origin}
	return writeYAMLAtomic(lockPath, lockfile)
}

type Lockfile struct {
	LockfileVersion int                    `yaml:"lockfileVersion"`
	Skills          map[string]LockedSkill `yaml:"skills"`
}

type LockedSkill struct {
	SkillID string     `yaml:"id"`
	Version string     `yaml:"version"`
	SHA256  string     `yaml:"sha256"`
	Origin  hub.Origin `yaml:"origin"`
}

func CheckNameConflict(root, name, skillID, ref string, mode install.Mode) error {
	manifestPath := filepath.Join(root, "skillsgo.yaml")
	if _, err := os.Stat(manifestPath); os.IsNotExist(err) {
		return nil
	} else if err != nil {
		return err
	}
	manifest, lockfile, err := Load(root)
	if err != nil {
		return err
	}
	if _, exists := manifest.Skills[name]; !exists {
		return nil
	}
	locked, exists := lockfile.Skills[name]
	if !exists {
		return fmt.Errorf("项目声明包含 Skill %q，但锁文件缺少对应记录", name)
	}
	if locked.SkillID != skillID {
		return fmt.Errorf("Skill 名称冲突：%q 已来自 %s，不能用 %s 静默覆盖", name, locked.SkillID, skillID)
	}
	existing := manifest.Skills[name]
	existingRef := existing.Ref
	if existingRef == "" {
		existingRef = "main"
	}
	if ref == "" {
		ref = "main"
	}
	if existingRef != ref {
		return fmt.Errorf("Skill %q 已跟踪 ref %q，不能静默改为 %q", name, existingRef, ref)
	}
	existingMode := existing.Mode
	if existingMode == "" {
		existingMode = install.ModeSymlink
	}
	if mode == "" {
		mode = install.ModeSymlink
	}
	if existingMode != mode {
		return fmt.Errorf("Skill %q 已使用 %s 模式，不能同时使用 %s 模式", name, existingMode, mode)
	}
	return nil
}

func RemoveBindings(root string, removed []install.Installation) error {
	manifestPath := filepath.Join(root, "skillsgo.yaml")
	if _, err := os.Stat(manifestPath); os.IsNotExist(err) {
		return nil
	} else if err != nil {
		return err
	}
	manifest, lockfile, err := Load(root)
	if err != nil {
		return err
	}
	removedAgents := map[string]map[string]bool{}
	for _, installation := range removed {
		if installation.Target.Scope != install.ScopeProject {
			continue
		}
		name := strings.ToLower(installation.Name)
		if removedAgents[name] == nil {
			removedAgents[name] = map[string]bool{}
		}
		removedAgents[name][installation.Target.Agent] = true
	}
	for name, requirement := range manifest.Skills {
		agentsToRemove := removedAgents[strings.ToLower(name)]
		if len(agentsToRemove) == 0 {
			continue
		}
		remaining := make([]string, 0, len(requirement.Agents))
		for _, agentID := range requirement.Agents {
			if !agentsToRemove[agentID] {
				remaining = append(remaining, agentID)
			}
		}
		if len(remaining) == 0 {
			delete(manifest.Skills, name)
			delete(lockfile.Skills, name)
			continue
		}
		requirement.Agents = remaining
		manifest.Skills[name] = requirement
	}
	if err := writeYAMLAtomic(manifestPath, manifest); err != nil {
		return err
	}
	return writeYAMLAtomic(filepath.Join(root, "skillsgo-lock.yaml"), lockfile)
}

func Upsert(root, name string, requirement SkillRequirement, receipt store.Receipt) error {
	return writeRequirement(root, name, requirement, receipt, true)
}

func Replace(root, name string, requirement SkillRequirement, receipt store.Receipt) error {
	return writeRequirement(root, name, requirement, receipt, false)
}

func writeRequirement(root, name string, requirement SkillRequirement, receipt store.Receipt, mergeAgents bool) error {
	manifestPath := filepath.Join(root, "skillsgo.yaml")
	manifest := Manifest{APIVersion: APIVersion, Skills: map[string]SkillRequirement{}}
	if err := readYAMLIfExists(manifestPath, &manifest); err != nil {
		return err
	}
	if manifest.APIVersion != APIVersion {
		return fmt.Errorf("不支持的 skillsgo.yaml apiVersion %q", manifest.APIVersion)
	}
	if manifest.Skills == nil {
		manifest.Skills = map[string]SkillRequirement{}
	}
	if existing, ok := manifest.Skills[name]; ok && mergeAgents {
		seen := map[string]bool{}
		merged := make([]string, 0, len(existing.Agents)+len(requirement.Agents))
		for _, agentID := range append(existing.Agents, requirement.Agents...) {
			if !seen[agentID] {
				seen[agentID] = true
				merged = append(merged, agentID)
			}
		}
		requirement.Agents = merged
	}
	requirement.Source = receipt.SkillID
	manifest.Skills[name] = requirement
	if err := writeYAMLAtomic(manifestPath, manifest); err != nil {
		return err
	}

	lockPath := filepath.Join(root, "skillsgo-lock.yaml")
	lockfile := Lockfile{LockfileVersion: 1, Skills: map[string]LockedSkill{}}
	if err := readYAMLIfExists(lockPath, &lockfile); err != nil {
		return err
	}
	if lockfile.LockfileVersion != 1 {
		return fmt.Errorf("不支持的 skillsgo-lock.yaml lockfileVersion %d", lockfile.LockfileVersion)
	}
	if lockfile.Skills == nil {
		lockfile.Skills = map[string]LockedSkill{}
	}
	lockfile.Skills[name] = LockedSkill{SkillID: receipt.SkillID, Version: receipt.Version, SHA256: receipt.SHA256, Origin: receipt.Origin}
	return writeYAMLAtomic(lockPath, lockfile)
}

func Load(root string) (Manifest, Lockfile, error) {
	var manifest Manifest
	if err := readRequiredYAML(filepath.Join(root, "skillsgo.yaml"), &manifest); err != nil {
		return Manifest{}, Lockfile{}, err
	}
	if manifest.APIVersion != APIVersion {
		return Manifest{}, Lockfile{}, fmt.Errorf("不支持的 skillsgo.yaml apiVersion %q", manifest.APIVersion)
	}
	var lockfile Lockfile
	if err := readRequiredYAML(filepath.Join(root, "skillsgo-lock.yaml"), &lockfile); err != nil {
		return Manifest{}, Lockfile{}, err
	}
	if lockfile.LockfileVersion != 1 {
		return Manifest{}, Lockfile{}, fmt.Errorf("不支持的 skillsgo-lock.yaml lockfileVersion %d", lockfile.LockfileVersion)
	}
	return manifest, lockfile, nil
}

func readRequiredYAML(path string, target any) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	if err := yaml.Unmarshal(data, target); err != nil {
		return fmt.Errorf("解析 %s: %w", path, err)
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
		return fmt.Errorf("解析 %s: %w", path, err)
	}
	return nil
}

func writeYAMLAtomic(path string, value any) error {
	data, err := yaml.Marshal(value)
	if err != nil {
		return err
	}
	temp, err := os.CreateTemp(filepath.Dir(path), ".skillsgo-yaml-")
	if err != nil {
		return err
	}
	tempName := temp.Name()
	defer os.Remove(tempName)
	if err := temp.Chmod(0o600); err != nil {
		temp.Close()
		return err
	}
	if _, err := temp.Write(data); err != nil {
		temp.Close()
		return err
	}
	if err := temp.Close(); err != nil {
		return err
	}
	return os.Rename(tempName, path)
}

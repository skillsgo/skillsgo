package install

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/skillsgo/skillsgo/cli/internal/store"
	"gopkg.in/yaml.v3"
)

type Installation struct {
	Name        string `json:"name"`
	Coordinate  string `json:"coordinate"`
	Version     string `json:"version"`
	StoreRoot   string `json:"storeRoot"`
	Artifact    string `json:"artifact"`
	ReceiptPath string `json:"-"`
	Target      Target `json:"target"`
	InstalledAt string `json:"installedAt"`
}

type InventoryFilter struct {
	Scope       *Scope
	Agents      map[string]bool
	ProjectRoot string
	Names       map[string]bool
}

func ListInstallations(storeRoot string, filter InventoryFilter) ([]Installation, error) {
	installations := make([]Installation, 0)
	err := filepath.WalkDir(storeRoot, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			if errors.Is(walkErr, os.ErrNotExist) {
				return nil
			}
			return walkErr
		}
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".yaml" || filepath.Base(filepath.Dir(path)) != "targets" {
			return nil
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		var targetReceipt TargetReceipt
		if err := yaml.Unmarshal(data, &targetReceipt); err != nil {
			return fmt.Errorf("解析安装回执 %s: %w", path, err)
		}
		target := Target{Agent: targetReceipt.Agent, Scope: targetReceipt.Scope, Mode: targetReceipt.Mode, Path: targetReceipt.Path}
		if !matchesFilter(target, filter) {
			return nil
		}
		entryRoot := filepath.Dir(filepath.Dir(path))
		receipt, err := store.ReadReceipt(filepath.Join(entryRoot, "receipt.yaml"))
		if err != nil {
			return fmt.Errorf("读取 Store 回执 %s: %w", entryRoot, err)
		}
		name := filepath.Base(target.Path)
		if len(filter.Names) > 0 && !filter.Names[strings.ToLower(name)] {
			return nil
		}
		installations = append(installations, Installation{
			Name: name, Coordinate: receipt.Coordinate, Version: receipt.Version,
			StoreRoot: entryRoot, Artifact: filepath.Join(entryRoot, "artifact"), ReceiptPath: path,
			Target: target, InstalledAt: targetReceipt.InstalledAt.Format("2006-01-02T15:04:05Z"),
		})
		return nil
	})
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return nil, err
	}
	sort.Slice(installations, func(i, j int) bool {
		if installations[i].Name != installations[j].Name {
			return installations[i].Name < installations[j].Name
		}
		return installations[i].Target.Agent < installations[j].Target.Agent
	})
	return installations, nil
}

func matchesFilter(target Target, filter InventoryFilter) bool {
	if filter.Scope != nil && target.Scope != *filter.Scope {
		return false
	}
	if len(filter.Agents) > 0 && !filter.Agents[target.Agent] {
		return false
	}
	if target.Scope == ScopeProject && filter.ProjectRoot != "" {
		projectRoot := resolveDirectory(filter.ProjectRoot)
		targetPath := filepath.Join(resolveDirectory(filepath.Dir(target.Path)), filepath.Base(target.Path))
		relative, err := filepath.Rel(projectRoot, targetPath)
		if err != nil || relative == ".." || strings.HasPrefix(relative, ".."+string(filepath.Separator)) {
			return false
		}
	}
	return true
}

func resolveDirectory(path string) string {
	resolved, err := filepath.EvalSymlinks(path)
	if err == nil {
		return resolved
	}
	absolute, err := filepath.Abs(path)
	if err == nil {
		return absolute
	}
	return filepath.Clean(path)
}

func RemoveInstallations(storeRoot string, installations []Installation) error {
	selected := map[string]bool{}
	for _, installation := range installations {
		selected[installation.ReceiptPath] = true
	}
	for _, installation := range installations {
		all, err := ListInstallations(storeRoot, InventoryFilter{})
		if err != nil {
			return err
		}
		usedByOtherReceipt := false
		for _, candidate := range all {
			if filepath.Clean(candidate.Target.Path) == filepath.Clean(installation.Target.Path) && !selected[candidate.ReceiptPath] {
				usedByOtherReceipt = true
				break
			}
		}
		if !usedByOtherReceipt {
			if err := removeTargetSafely(installation); err != nil {
				return err
			}
		}
		if err := os.Remove(installation.ReceiptPath); err != nil && !os.IsNotExist(err) {
			return err
		}
	}
	return nil
}

func removeTargetSafely(installation Installation) error {
	info, err := os.Lstat(installation.Target.Path)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	if installation.Target.Mode == ModeSymlink {
		if info.Mode()&os.ModeSymlink == 0 {
			return fmt.Errorf("拒绝移除已被替换的目标 %s", installation.Target.Path)
		}
		link, err := os.Readlink(installation.Target.Path)
		if err != nil {
			return err
		}
		if !filepath.IsAbs(link) {
			link = filepath.Join(filepath.Dir(installation.Target.Path), link)
		}
		if !samePath(link, installation.Artifact) {
			return fmt.Errorf("拒绝移除指向其他位置的软链 %s", installation.Target.Path)
		}
		return os.Remove(installation.Target.Path)
	}
	if !info.IsDir() {
		return fmt.Errorf("拒绝移除不是目录的复制目标 %s", installation.Target.Path)
	}
	return os.RemoveAll(installation.Target.Path)
}

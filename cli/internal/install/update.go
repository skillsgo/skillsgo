/*
 * [INPUT]: Depends on a new immutable Store entry, declaration-derived prior Installations, resolved targets, and optional explicit replacement authority.
 * [OUTPUT]: Provides rollback-capable tracked replacement with metadata callbacks and explicitly authorized collision/Local Modification replacement.
 * [POS]: Serves as the atomic target-switching boundary beneath update and resolved Installation Plan operations.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package install

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/skillsgo/skillsgo/cli/internal/store"
)

// Replace switches tracked targets to a new immutable Store entry. Every path
// is switched with a backup so a failed rename can restore the previous target.
func Replace(entry *store.Entry, previous []Installation, targets []Target) error {
	return replace(entry, previous, targets, false, nil)
}

// ReplaceThen retains replacement backups until the higher-level persistence
// callback succeeds, without relaxing tracked-target integrity checks.
func ReplaceThen(entry *store.Entry, previous []Installation, targets []Target, after func() error) error {
	return replace(entry, previous, targets, false, after)
}

// ReplaceExplicit switches targets after the caller has received an explicit
// per-target replacement decision. It may replace an untracked path or a
// tracked target whose contents no longer match its receipt.
func ReplaceExplicit(entry *store.Entry, previous []Installation, targets []Target) error {
	return replace(entry, previous, targets, true, nil)
}

// ReplaceExplicitThen retains replacement backups until the higher-level
// persistence callback succeeds, and restores every switched target on error.
func ReplaceExplicitThen(entry *store.Entry, previous []Installation, targets []Target, after func() error) error {
	return replace(entry, previous, targets, true, after)
}

func replace(entry *store.Entry, previous []Installation, targets []Target, explicit bool, after func() error) error {
	canonicalTargetsOnly := true
	hasCanonicalTarget := false
	for _, target := range targets {
		if target.Mode == ModeSymlink && target.CanonicalPath != "" {
			hasCanonicalTarget = true
		} else {
			canonicalTargetsOnly = false
		}
	}
	if hasCanonicalTarget && canonicalTargetsOnly {
		return replaceCanonical(entry, previous, targets, explicit, after)
	}
	switched := make([]switchAction, 0, len(targets))
	seen := map[string]bool{}
	for _, target := range targets {
		path := filepath.Clean(target.Path)
		if seen[path] {
			continue
		}
		seen[path] = true
		var old Installation
		tracked := false
		for _, installation := range previous {
			// A physical target and one of its symlink projections resolve to the
			// same inode. Receipts identify them by their exact lexical paths.
			if filepath.Clean(installation.Target.Path) == path {
				old, tracked = installation, true
				break
			}
		}
		action, err := replaceTarget(entry.Artifact, target, old, tracked, explicit)
		if err != nil {
			for index := len(switched) - 1; index >= 0; index-- {
				switched[index].rollback()
			}
			return err
		}
		switched = append(switched, action)
	}
	if after != nil {
		if err := after(); err != nil {
			for index := len(switched) - 1; index >= 0; index-- {
				switched[index].rollback()
			}
			return err
		}
	}
	for _, action := range switched {
		if err := action.commit(); err != nil {
			return err
		}
	}
	for _, installation := range previous {
		stillDesired := false
		for _, target := range targets {
			if samePath(installation.Target.Path, target.Path) {
				stillDesired = true
				break
			}
		}
		if !stillDesired {
			if err := removeTargetSafely(installation); err != nil {
				return err
			}
		}
	}
	return nil
}

func replaceCanonical(entry *store.Entry, previous []Installation, targets []Target, explicit bool, after func() error) error {
	canonical := filepath.Clean(targets[0].CanonicalPath)
	canonicalSelected := false
	for _, target := range targets {
		if target.Mode != ModeSymlink || filepath.Clean(target.CanonicalPath) != canonical {
			return fmt.Errorf("一次替换不能混用 canonical 或安装模式")
		}
		if filepath.Clean(target.Path) == canonical {
			canonicalSelected = true
		}
	}
	canonicalExists := false
	canonicalRealDirectory := false
	canonicalMatchesDesired := false
	if info, err := os.Lstat(canonical); err == nil {
		canonicalExists = true
		canonicalRealDirectory = info.IsDir() && info.Mode()&os.ModeSymlink == 0
		if !canonicalRealDirectory && !explicit {
			return fmt.Errorf("canonical 目标必须是实体目录：%s", canonical)
		}
		if canonicalRealDirectory {
			canonicalMatchesDesired, _ = CopyMatchesArtifact(canonical, entry.Artifact)
			if explicit && !canonicalSelected && !canonicalMatchesDesired {
				return fmt.Errorf("拒绝替换已修改的 canonical 目标 %s", canonical)
			}
			trackedBaseline := false
			for _, installation := range previous {
				if filepath.Clean(installation.Target.CanonicalPath) != canonical {
					continue
				}
				trackedBaseline = true
				matched := false
				if installation.Artifact != "" {
					matched, _ = CopyMatchesArtifact(canonical, installation.Artifact)
				}
				if !matched && !canonicalMatchesDesired && !explicit {
					return fmt.Errorf("拒绝替换已修改的 canonical 目标 %s", canonical)
				}
				break
			}
			if !trackedBaseline && !canonicalMatchesDesired && !explicit {
				return fmt.Errorf("拒绝替换已修改的 canonical 目标 %s", canonical)
			}
		}
	} else if !os.IsNotExist(err) {
		return err
	}
	backup := canonical + ".skillsgo-backup"
	canonicalSwitched := !canonicalExists || !canonicalRealDirectory || !canonicalMatchesDesired
	if canonicalSwitched {
		_ = os.RemoveAll(backup)
		if canonicalExists {
			if err := os.Rename(canonical, backup); err != nil {
				return err
			}
		}
		if err := installTarget(entry.Artifact, canonical, ModeCopy); err != nil {
			_ = os.Rename(backup, canonical)
			return err
		}
	}
	rollbackCanonical := func() {
		if !canonicalSwitched {
			return
		}
		_ = os.RemoveAll(canonical)
		_ = os.Rename(backup, canonical)
	}
	targetSwitches := make([]switchAction, 0, len(targets))
	rollback := func() {
		for index := len(targetSwitches) - 1; index >= 0; index-- {
			targetSwitches[index].rollback()
		}
		rollbackCanonical()
	}
	for _, target := range targets {
		if filepath.Clean(target.Path) == canonical {
			continue
		}
		if info, err := os.Lstat(target.Path); err == nil {
			if info.Mode()&os.ModeSymlink != 0 {
				link, readErr := os.Readlink(target.Path)
				if readErr != nil {
					rollback()
					return readErr
				}
				if !filepath.IsAbs(link) {
					link = filepath.Join(filepath.Dir(target.Path), link)
				}
				if samePath(link, canonical) {
					continue
				}
			}
			if !explicit {
				rollback()
				return fmt.Errorf("目标已存在且未指向 canonical：%s", target.Path)
			}
			targetBackup := target.Path + ".skillsgo-backup"
			if _, backupErr := os.Lstat(targetBackup); backupErr == nil {
				rollback()
				return fmt.Errorf("更新备份路径已存在：%s", targetBackup)
			} else if !os.IsNotExist(backupErr) {
				rollback()
				return backupErr
			}
			if err := os.Rename(target.Path, targetBackup); err != nil {
				rollback()
				return err
			}
			action := switchAction{
				rollback: func() {
					_ = os.RemoveAll(target.Path)
					_ = os.Rename(targetBackup, target.Path)
				},
				commit: func() error { return os.RemoveAll(targetBackup) },
			}
			targetSwitches = append(targetSwitches, action)
			if err := installTarget(canonical, target.Path, ModeSymlink); err != nil {
				rollback()
				return err
			}
			continue
		} else if !os.IsNotExist(err) {
			rollback()
			return err
		}
		if err := installTarget(canonical, target.Path, ModeSymlink); err != nil {
			rollback()
			return err
		}
	}
	if after != nil {
		if err := after(); err != nil {
			rollback()
			return err
		}
	}
	for _, old := range previous {
		if targetPathDesired(old.Target.Path, targets) || filepath.Clean(old.Target.Path) == canonical {
			continue
		}
		if err := removeTargetSafely(old); err != nil {
			rollback()
			return err
		}
	}
	for _, action := range targetSwitches {
		if err := action.commit(); err != nil {
			return err
		}
	}
	if canonicalSwitched {
		return os.RemoveAll(backup)
	}
	return nil
}

func targetPathDesired(path string, targets []Target) bool {
	for _, target := range targets {
		if filepath.Clean(path) == filepath.Clean(target.Path) {
			return true
		}
	}
	return false
}

type switchAction struct {
	rollback func()
	commit   func() error
}

func replaceTarget(artifact string, target Target, previous Installation, tracked, explicit bool) (switchAction, error) {
	path := filepath.Clean(target.Path)
	desiredSource := artifact
	if target.Mode == ModeSymlink && target.CanonicalPath != "" {
		desiredSource = target.CanonicalPath
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return switchAction{}, err
	}
	if _, err := os.Lstat(path); os.IsNotExist(err) {
		if err := installTarget(desiredSource, path, target.Mode); err != nil {
			return switchAction{}, err
		}
		return switchAction{rollback: func() { _ = os.RemoveAll(path) }, commit: func() error { return nil }}, nil
	} else if err != nil {
		return switchAction{}, err
	}
	if !tracked && !explicit {
		return switchAction{}, fmt.Errorf("拒绝更新未被声明管理的目标 %s", path)
	}
	if tracked && target.Mode != previous.Target.Mode && !explicit {
		return switchAction{}, fmt.Errorf("目标 %s 的安装模式从 %s 变成了 %s", path, previous.Target.Mode, target.Mode)
	}
	if tracked && target.Mode == ModeSymlink && !explicit {
		info, err := os.Lstat(path)
		if err != nil || info.Mode()&os.ModeSymlink == 0 {
			return switchAction{}, fmt.Errorf("拒绝替换不是软链的受管目标 %s", path)
		}
		link, err := os.Readlink(path)
		if err != nil {
			return switchAction{}, err
		}
		if !filepath.IsAbs(link) {
			link = filepath.Join(filepath.Dir(path), link)
		}
		expected := previous.Artifact
		if previous.Target.CanonicalPath != "" {
			expected = previous.Target.CanonicalPath
		}
		if !samePath(link, expected) {
			return switchAction{}, fmt.Errorf("拒绝替换已指向其他位置的软链 %s", path)
		}
	}
	if tracked && target.Mode == ModeCopy && !explicit {
		matched := false
		if previous.TargetState != "" {
			actual, err := DirectoryDigest(path)
			if err != nil {
				return switchAction{}, err
			}
			matched = actual == previous.TargetState
		} else if previous.Artifact != "" {
			matched, _ = CopyMatchesArtifact(path, previous.Artifact)
		}
		if !matched {
			return switchAction{}, fmt.Errorf("拒绝替换已修改的复制目标 %s", path)
		}
	}

	backup := path + ".skillsgo-backup"
	if _, err := os.Lstat(backup); err == nil {
		return switchAction{}, fmt.Errorf("更新备份路径已存在：%s", backup)
	} else if !os.IsNotExist(err) {
		return switchAction{}, err
	}
	if err := os.Rename(path, backup); err != nil {
		return switchAction{}, err
	}
	if err := installTarget(desiredSource, path, target.Mode); err != nil {
		_ = os.Rename(backup, path)
		return switchAction{}, err
	}
	return switchAction{
		rollback: func() {
			_ = os.RemoveAll(path)
			_ = os.Rename(backup, path)
		},
		commit: func() error { return os.RemoveAll(backup) },
	}, nil
}

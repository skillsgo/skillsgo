/*
 * [INPUT]: Depends on a new immutable Store entry, prior Installation Receipts, resolved targets, and explicit replacement authority.
 * [OUTPUT]: Provides rollback-capable tracked replacement and explicitly authorized collision/Local Modification replacement.
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
	return replace(entry, previous, targets, false)
}

// ReplaceExplicit switches targets after the caller has received an explicit
// per-target replacement decision. It may replace an untracked path or a
// tracked target whose contents no longer match its receipt.
func ReplaceExplicit(entry *store.Entry, previous []Installation, targets []Target) error {
	return replace(entry, previous, targets, true)
}

func replace(entry *store.Entry, previous []Installation, targets []Target, explicit bool) error {
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
			if samePath(installation.Target.Path, path) {
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
	for _, target := range targets {
		if err := writeTargetReceipt(entry.Root, target); err != nil {
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
	for _, installation := range previous {
		if samePath(installation.StoreRoot, entry.Root) && targetPathDesired(installation.Target.Path, targets) {
			continue
		}
		if err := os.Remove(installation.ReceiptPath); err != nil && !os.IsNotExist(err) {
			return err
		}
	}
	return nil
}

func targetPathDesired(path string, targets []Target) bool {
	for _, target := range targets {
		if samePath(path, target.Path) {
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
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return switchAction{}, err
	}
	if _, err := os.Lstat(path); os.IsNotExist(err) {
		if err := installTarget(artifact, path, target.Mode); err != nil {
			return switchAction{}, err
		}
		return switchAction{rollback: func() { _ = os.RemoveAll(path) }, commit: func() error { return nil }}, nil
	} else if err != nil {
		return switchAction{}, err
	}
	if !tracked && !explicit {
		return switchAction{}, fmt.Errorf("拒绝更新未被 Store 回执跟踪的目标 %s", path)
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
		if !samePath(link, previous.Artifact) {
			return switchAction{}, fmt.Errorf("拒绝替换已指向其他位置的软链 %s", path)
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
	if err := installTarget(artifact, path, target.Mode); err != nil {
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

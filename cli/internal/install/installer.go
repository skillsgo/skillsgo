package install

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"time"

	"github.com/skillsgo/skillsgo/cli/internal/store"
	"gopkg.in/yaml.v3"
)

type TargetReceipt struct {
	Agent       string    `yaml:"agent"`
	Scope       Scope     `yaml:"scope"`
	Mode        Mode      `yaml:"mode"`
	Path        string    `yaml:"path"`
	InstalledAt time.Time `yaml:"installedAt"`
}

func Install(entry *store.Entry, targets []Target) error {
	installedPaths := map[string]Mode{}
	for _, target := range targets {
		cleanPath := filepath.Clean(target.Path)
		if previousMode, ok := installedPaths[cleanPath]; ok {
			if previousMode != target.Mode {
				return fmt.Errorf("目标 %q 同时使用了 %s 和 %s 安装模式", cleanPath, previousMode, target.Mode)
			}
		} else {
			if err := installTarget(entry.Artifact, cleanPath, target.Mode); err != nil {
				return fmt.Errorf("安装 %s 到 %s: %w", target.Agent, cleanPath, err)
			}
			installedPaths[cleanPath] = target.Mode
		}
		if err := writeTargetReceipt(entry.Root, target); err != nil {
			return err
		}
	}
	return nil
}

func installTarget(artifact, target string, mode Mode) error {
	if err := os.MkdirAll(filepath.Dir(target), 0o700); err != nil {
		return err
	}
	if info, err := os.Lstat(target); err == nil {
		if mode == ModeSymlink && info.Mode()&os.ModeSymlink != 0 {
			link, readErr := os.Readlink(target)
			if readErr == nil {
				resolved := link
				if !filepath.IsAbs(link) {
					resolved = filepath.Join(filepath.Dir(target), link)
				}
				if samePath(resolved, artifact) {
					return nil
				}
			}
		}
		return fmt.Errorf("目标已存在；请先移除：%s", target)
	} else if !os.IsNotExist(err) {
		return err
	}

	switch mode {
	case ModeSymlink:
		relative, err := filepath.Rel(filepath.Dir(target), artifact)
		if err != nil {
			return err
		}
		return os.Symlink(relative, target)
	case ModeCopy:
		return copyDirectoryAtomic(artifact, target)
	default:
		return fmt.Errorf("未知安装模式 %q", mode)
	}
}

func copyDirectoryAtomic(source, target string) error {
	temp, err := os.MkdirTemp(filepath.Dir(target), ".skillsgo-install-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(temp)
	if err := copyDirectory(source, temp); err != nil {
		return err
	}
	return os.Rename(temp, target)
}

func copyDirectory(source, destination string) error {
	return filepath.WalkDir(source, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		relative, err := filepath.Rel(source, path)
		if err != nil {
			return err
		}
		target := filepath.Join(destination, relative)
		info, err := entry.Info()
		if err != nil {
			return err
		}
		if entry.IsDir() {
			return os.MkdirAll(target, info.Mode().Perm())
		}
		if !info.Mode().IsRegular() {
			return fmt.Errorf("制品包含不支持的文件类型 %q", path)
		}
		input, err := os.Open(path)
		if err != nil {
			return err
		}
		defer input.Close()
		output, err := os.OpenFile(target, os.O_CREATE|os.O_EXCL|os.O_WRONLY, info.Mode().Perm())
		if err != nil {
			return err
		}
		_, copyErr := io.Copy(output, input)
		closeErr := output.Close()
		if copyErr != nil {
			return copyErr
		}
		return closeErr
	})
}

func writeTargetReceipt(entryRoot string, target Target) error {
	receipt := TargetReceipt{Agent: target.Agent, Scope: target.Scope, Mode: target.Mode, Path: filepath.Clean(target.Path), InstalledAt: time.Now().UTC()}
	data, err := yaml.Marshal(receipt)
	if err != nil {
		return err
	}
	digest := sha256.Sum256([]byte(receipt.Agent + "\x00" + string(receipt.Scope) + "\x00" + receipt.Path))
	name := receipt.Agent + "-" + hex.EncodeToString(digest[:8]) + ".yaml"
	directory := filepath.Join(entryRoot, "targets")
	if err := os.MkdirAll(directory, 0o700); err != nil {
		return err
	}
	temp, err := os.CreateTemp(directory, ".receipt-")
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
	return os.Rename(tempName, filepath.Join(directory, name))
}

func samePath(left, right string) bool {
	realLeft, realLeftErr := filepath.EvalSymlinks(left)
	realRight, realRightErr := filepath.EvalSymlinks(right)
	if realLeftErr == nil && realRightErr == nil {
		left, right = realLeft, realRight
	}
	absLeft, errLeft := filepath.Abs(left)
	absRight, errRight := filepath.Abs(right)
	return errLeft == nil && errRight == nil && filepath.Clean(absLeft) == filepath.Clean(absRight)
}

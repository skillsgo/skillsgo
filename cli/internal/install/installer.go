/*
 * [INPUT]: Depends on immutable Store entries, resolved Agent targets, and filesystem metadata.
 * [OUTPUT]: Provides rollback-capable canonical materialization plus alias-aware Agent symlink/copy projection, content-preserving existing-target validation, and stable filesystem digests.
 * [POS]: Serves as the low-level materialization boundary used by Installation Plans and legacy CLI flows.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package install

import (
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"

	hubclient "github.com/skillsgo/skillsgo/cli/internal/hub"
	"github.com/skillsgo/skillsgo/cli/internal/store"
)

func Install(entry *store.Entry, targets []Target) error {
	return InstallThen(entry, targets, nil)
}

// InstallThen keeps track of paths created by this operation and removes them
// if the higher-level persistence callback fails.
func InstallThen(entry *store.Entry, targets []Target, after func() error) error {
	installedPaths := map[string]Mode{}
	created := make([]string, 0, len(targets)*2)
	seenCreated := map[string]bool{}
	rememberAbsent := func(path string) {
		path = filepath.Clean(path)
		if path == "." || seenCreated[path] {
			return
		}
		if _, err := os.Lstat(path); os.IsNotExist(err) {
			seenCreated[path] = true
			created = append(created, path)
		}
	}
	rollback := func() {
		for index := len(created) - 1; index >= 0; index-- {
			_ = os.RemoveAll(created[index])
		}
	}
	for _, target := range targets {
		cleanPath := filepath.Clean(target.Path)
		if previousMode, ok := installedPaths[cleanPath]; ok {
			if previousMode != target.Mode {
				rollback()
				return fmt.Errorf("目标 %q 同时使用了 %s 和 %s 安装模式", cleanPath, previousMode, target.Mode)
			}
		} else {
			rememberAbsent(cleanPath)
			if target.Mode == ModeSymlink && target.CanonicalPath != "" {
				rememberAbsent(target.CanonicalPath)
			}
			if err := installResolvedTarget(entry.Artifact, target); err != nil {
				rollback()
				return fmt.Errorf("安装 %s 到 %s: %w", target.Agent, cleanPath, err)
			}
			installedPaths[cleanPath] = target.Mode
		}
	}
	if after != nil {
		if err := after(); err != nil {
			rollback()
			return err
		}
	}
	return nil
}

func installResolvedTarget(artifact string, target Target) error {
	if target.Mode == ModeCopy {
		return installTarget(artifact, filepath.Clean(target.Path), ModeCopy)
	}
	canonical := filepath.Clean(target.CanonicalPath)
	if canonical == "." || target.CanonicalPath == "" {
		return fmt.Errorf("软链安装缺少 canonical 路径")
	}
	if err := ensureCanonical(artifact, canonical); err != nil {
		return err
	}
	if filepath.Clean(canonical) == filepath.Clean(target.Path) || samePath(canonical, target.Path) {
		return nil
	}
	return installTarget(canonical, filepath.Clean(target.Path), ModeSymlink)
}

func ensureCanonical(artifact, canonical string) error {
	info, err := os.Lstat(canonical)
	if os.IsNotExist(err) {
		return installTarget(artifact, canonical, ModeCopy)
	}
	if err != nil {
		return err
	}
	if !info.IsDir() || info.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf("canonical 目标已存在且不是实体目录：%s", canonical)
	}
	matches, err := CopyMatchesArtifact(canonical, artifact)
	if err != nil {
		return err
	}
	if !matches {
		return fmt.Errorf("canonical 目标已存在且内容不同：%s", canonical)
	}
	return nil
}

// AdoptExisting validates an exact external directory before its declaration
// is added without replacing, rewriting, or relinking its current content.
func AdoptExisting(entry *store.Entry, target Target) error {
	if target.Mode != ModeCopy {
		return fmt.Errorf("existing targets can be adopted only in copy mode")
	}
	info, err := os.Lstat(target.Path)
	if err != nil {
		return err
	}
	if !info.IsDir() {
		return fmt.Errorf("existing target must be a real directory")
	}
	if err := hubclient.VerifyContentDirectory(target.Path, entry.Receipt.ContentDigest); err != nil {
		return fmt.Errorf("existing target content does not match reviewed artifact: %w", err)
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

// DirectoryDigest returns a stable digest of directory entries, relative
// paths, permission bits, and regular-file contents. It is used to detect
// copy-mode Local Modifications from live filesystem state.
func DirectoryDigest(root string) (string, error) {
	hash := sha256.New()
	_, _ = hash.Write([]byte("skillsgo-directory-digest-v1\x00"))
	err := filepath.WalkDir(root, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if path == root {
			return nil
		}
		relative, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		kind := byte('f')
		if entry.IsDir() {
			kind = 'd'
		} else if !info.Mode().IsRegular() {
			return fmt.Errorf("unsupported target file type %q", path)
		}
		relativeBytes := []byte(filepath.ToSlash(relative))
		_, _ = hash.Write([]byte{kind})
		if err := binary.Write(hash, binary.BigEndian, uint64(len(relativeBytes))); err != nil {
			return err
		}
		_, _ = hash.Write(relativeBytes)
		if err := binary.Write(hash, binary.BigEndian, uint32(info.Mode().Perm())); err != nil {
			return err
		}
		if entry.IsDir() {
			return nil
		}
		if err := binary.Write(hash, binary.BigEndian, uint64(info.Size())); err != nil {
			return err
		}
		file, err := os.Open(path)
		if err != nil {
			return err
		}
		_, copyErr := io.Copy(hash, file)
		closeErr := file.Close()
		if copyErr != nil {
			return copyErr
		}
		if closeErr != nil {
			return closeErr
		}
		return nil
	})
	if err != nil {
		return "", err
	}
	return hex.EncodeToString(hash.Sum(nil)), nil
}

// CopyMatchesArtifact compares a copy-mode target with its immutable Store artifact.
func CopyMatchesArtifact(target, artifact string) (bool, error) {
	targetDigest, err := DirectoryDigest(target)
	if err != nil {
		return false, err
	}
	artifactDigest, err := DirectoryDigest(artifact)
	if err != nil {
		return false, err
	}
	return targetDigest == artifactDigest, nil
}

// TargetStateDigest returns a framed digest for the exact filesystem object
// currently occupying an Installation Target path.
func TargetStateDigest(path string) (string, error) {
	hash := sha256.New()
	_, _ = hash.Write([]byte("skillsgo-target-state-v1\x00"))
	info, err := os.Lstat(path)
	if os.IsNotExist(err) {
		_, _ = hash.Write([]byte("missing"))
		return hex.EncodeToString(hash.Sum(nil)), nil
	}
	if err != nil {
		return "", err
	}
	switch {
	case info.Mode()&os.ModeSymlink != 0:
		link, err := os.Readlink(path)
		if err != nil {
			return "", err
		}
		_, _ = hash.Write([]byte("symlink"))
		if err := binary.Write(hash, binary.BigEndian, uint64(len(link))); err != nil {
			return "", err
		}
		_, _ = io.WriteString(hash, link)
	case info.IsDir():
		digest, err := DirectoryDigest(path)
		if err != nil {
			return "", err
		}
		_, _ = hash.Write([]byte("directory"))
		if err := binary.Write(hash, binary.BigEndian, uint32(info.Mode().Perm())); err != nil {
			return "", err
		}
		_, _ = io.WriteString(hash, digest)
	case info.Mode().IsRegular():
		_, _ = hash.Write([]byte("file"))
		if err := binary.Write(hash, binary.BigEndian, uint32(info.Mode().Perm())); err != nil {
			return "", err
		}
		if err := binary.Write(hash, binary.BigEndian, uint64(info.Size())); err != nil {
			return "", err
		}
		file, err := os.Open(path)
		if err != nil {
			return "", err
		}
		_, copyErr := io.Copy(hash, file)
		closeErr := file.Close()
		if copyErr != nil {
			return "", copyErr
		}
		if closeErr != nil {
			return "", closeErr
		}
	default:
		return "", fmt.Errorf("unsupported target file type %q", path)
	}
	return hex.EncodeToString(hash.Sum(nil)), nil
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

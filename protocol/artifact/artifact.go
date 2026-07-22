/*
 * [INPUT]: Depends on immutable SkillsGo ZIP bytes, extracted regular-file directories, and canonical artifact identity.
 * [OUTPUT]: Provides shared artifact limits, portable collision-safe path validation, canonical mode checks, one-pass normalized ZIP traversal, Sum calculation, and declared-digest verification.
 * [POS]: Serves as the executable artifact-format contract shared by Hub producers and CLI consumers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package artifact

import (
	"archive/zip"
	"bytes"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"io"
	"os"
	"path"
	"path/filepath"
	"sort"
	"strings"
	"unicode/utf8"

	"golang.org/x/mod/module"
	"golang.org/x/text/cases"
	"golang.org/x/text/unicode/norm"
)

const (
	MaxArchiveBytes      = 64 << 20
	MaxFiles             = 5000
	MaxUncompressedBytes = 64 << 20
)

// Entry is one validated file or explicit directory in normalized artifact-path order.
type Entry struct {
	Path      string
	Contents  []byte
	Mode      os.FileMode
	Size      int64
	Directory bool
}

// VisitFunc observes each validated artifact entry while its Sum is
// calculated. File contents are owned by the call and must not be retained.
type VisitFunc func(Entry) error

func ValidRelativePath(value string) bool {
	_, err := PortablePathKey(value)
	return err == nil
}

// PortablePathKey validates one artifact-relative path and returns the key
// used to reject Unicode/case-insensitive filesystem collisions.
func PortablePathKey(value string) (string, error) {
	if value == "" || value == "." || !utf8.ValidString(value) || strings.HasPrefix(value, "/") ||
		strings.Contains(value, "\\") || path.Clean(value) != value ||
		value == ".." || strings.HasPrefix(value, "../") {
		return "", fmt.Errorf("invalid relative path %q", value)
	}
	if err := module.CheckFilePath(value); err != nil {
		return "", fmt.Errorf("path %q is not portable: %w", value, err)
	}
	for _, segment := range strings.Split(value, "/") {
		if strings.HasSuffix(segment, " ") {
			return "", fmt.Errorf("path %q has a Windows-ambiguous trailing space", value)
		}
	}
	return cases.Fold().String(norm.NFC.String(value)), nil
}

func ValidSum(value string) bool {
	if !strings.HasPrefix(value, "h1:") {
		return false
	}
	decoded, err := base64.StdEncoding.DecodeString(strings.TrimPrefix(value, "h1:"))
	return err == nil && len(decoded) == sha256.Size
}

func Sum(data []byte, skillID, version string) (string, error) {
	return WalkContent(data, skillID, version, nil)
}

// WalkContent validates and reads an artifact exactly once, visits files in
// normalized path order, and returns the Sum over the same entries.
func WalkContent(data []byte, skillID, version string, visit VisitFunc) (string, error) {
	if len(data) == 0 || len(data) > MaxArchiveBytes {
		return "", fmt.Errorf("artifact archive size must be between 1 and %d bytes", MaxArchiveBytes)
	}
	reader, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		return "", fmt.Errorf("open artifact archive: %w", err)
	}
	if len(reader.File) > MaxFiles {
		return "", fmt.Errorf("artifact contains more than %d files", MaxFiles)
	}
	entries := append([]*zip.File(nil), reader.File...)
	sort.Slice(entries, func(i, j int) bool { return entries[i].Name < entries[j].Name })
	type seenPath struct {
		path      string
		directory bool
	}
	prefix, hash, seen := skillID+"@"+version+"/", sha256.New(), map[string]seenPath{}
	var total uint64
	for _, entry := range entries {
		if !strings.HasPrefix(entry.Name, prefix) {
			return "", fmt.Errorf("artifact file %q is outside expected prefix %q", entry.Name, prefix)
		}
		relative := strings.TrimPrefix(entry.Name, prefix)
		if entry.FileInfo().IsDir() {
			relative = strings.TrimSuffix(relative, "/")
			if relative == "" {
				continue
			}
			collisionKey, pathErr := PortablePathKey(relative)
			if pathErr != nil {
				return "", pathErr
			}
			if previous, exists := seen[collisionKey]; exists {
				return "", fmt.Errorf("artifact paths %q and %q collide on portable filesystems", previous.path, relative)
			}
			seen[collisionKey] = seenPath{path: relative, directory: true}
			if visit != nil {
				if err := visit(Entry{Path: relative, Mode: entry.Mode(), Directory: true}); err != nil {
					return "", fmt.Errorf("visit artifact directory %q: %w", relative, err)
				}
			}
			continue
		}
		if entry.Method != zip.Store && entry.Method != zip.Deflate {
			return "", fmt.Errorf("artifact file %q uses unsupported compression method %d", relative, entry.Method)
		}
		if !entry.Mode().IsRegular() {
			return "", fmt.Errorf("artifact file %q is not a regular file", relative)
		}
		collisionKey, pathErr := PortablePathKey(relative)
		if pathErr != nil {
			return "", pathErr
		}
		if previous, exists := seen[collisionKey]; exists {
			return "", fmt.Errorf("artifact paths %q and %q collide on portable filesystems", previous.path, relative)
		}
		for parent := path.Dir(relative); parent != "."; parent = path.Dir(parent) {
			parentKey, _ := PortablePathKey(parent)
			if previous, exists := seen[parentKey]; exists && !previous.directory {
				return "", fmt.Errorf("artifact file %q conflicts with parent file %q", relative, previous.path)
			}
		}
		seen[collisionKey] = seenPath{path: relative}
		if entry.UncompressedSize64 > MaxUncompressedBytes || total > MaxUncompressedBytes-entry.UncompressedSize64 {
			return "", fmt.Errorf("artifact expands beyond %d bytes", MaxUncompressedBytes)
		}
		total += entry.UncompressedSize64
		contents, err := ReadEntry(entry)
		if err != nil {
			return "", fmt.Errorf("read artifact file %q: %w", relative, err)
		}
		if err := writeHash1Content(hash, relative, contents); err != nil {
			return "", err
		}
		if visit != nil {
			if err := visit(Entry{Path: relative, Contents: contents, Mode: entry.Mode(), Size: int64(entry.UncompressedSize64)}); err != nil {
				return "", fmt.Errorf("visit artifact file %q: %w", relative, err)
			}
		}
	}
	manifestKey, _ := PortablePathKey("SKILL.md")
	if manifest, exists := seen[manifestKey]; !exists || manifest.path != "SKILL.md" || manifest.directory {
		return "", fmt.Errorf("artifact does not contain SKILL.md")
	}
	return "h1:" + base64.StdEncoding.EncodeToString(hash.Sum(nil)), nil
}

func DirectorySum(root string) (string, error) {
	root, err := filepath.Abs(root)
	if err != nil {
		return "", err
	}
	paths := make([]string, 0)
	seen := make(map[string]string)
	var total uint64
	err = filepath.WalkDir(root, func(current string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if current == root || entry.IsDir() {
			return nil
		}
		info, err := entry.Info()
		if err != nil {
			return err
		}
		if !info.Mode().IsRegular() || info.Size() < 0 {
			return fmt.Errorf("artifact contains unsupported file %q", current)
		}
		relative, err := filepath.Rel(root, current)
		if err != nil {
			return err
		}
		relative = filepath.ToSlash(relative)
		collisionKey, pathErr := PortablePathKey(relative)
		if pathErr != nil {
			return fmt.Errorf("artifact contains invalid path %q: %w", relative, pathErr)
		}
		if previous, exists := seen[collisionKey]; exists {
			return fmt.Errorf("artifact paths %q and %q collide on portable filesystems", previous, relative)
		}
		seen[collisionKey] = relative
		size := uint64(info.Size())
		if size > MaxUncompressedBytes || total > MaxUncompressedBytes-size {
			return fmt.Errorf("artifact exceeds %d bytes", MaxUncompressedBytes)
		}
		total += size
		paths = append(paths, relative)
		if len(paths) > MaxFiles {
			return fmt.Errorf("artifact contains more than %d files", MaxFiles)
		}
		return nil
	})
	if err != nil {
		return "", err
	}
	sort.Strings(paths)
	hash := sha256.New()
	for _, relative := range paths {
		contents, err := os.ReadFile(filepath.Join(root, filepath.FromSlash(relative)))
		if err != nil {
			return "", err
		}
		if len(contents) > MaxUncompressedBytes {
			return "", fmt.Errorf("file exceeds %d bytes", MaxUncompressedBytes)
		}
		if err := writeHash1Content(hash, relative, contents); err != nil {
			return "", err
		}
	}
	if info, err := os.Stat(filepath.Join(root, "SKILL.md")); err != nil || !info.Mode().IsRegular() {
		return "", fmt.Errorf("artifact does not contain a regular SKILL.md")
	}
	return "h1:" + base64.StdEncoding.EncodeToString(hash.Sum(nil)), nil
}

func ReadEntry(entry *zip.File) ([]byte, error) {
	reader, err := entry.Open()
	if err != nil {
		return nil, err
	}
	defer reader.Close()
	return readBounded(reader, entry.UncompressedSize64)
}

func readBounded(reader io.Reader, declaredSize uint64) ([]byte, error) {
	contents, err := io.ReadAll(io.LimitReader(reader, MaxUncompressedBytes+1))
	if err != nil {
		return nil, err
	}
	if len(contents) > MaxUncompressedBytes || uint64(len(contents)) != declaredSize {
		return nil, fmt.Errorf("uncompressed size does not match archive metadata")
	}
	return contents, nil
}

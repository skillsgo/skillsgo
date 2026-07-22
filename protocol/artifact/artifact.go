/*
 * [INPUT]: Depends on immutable SkillsGo ZIP bytes, extracted regular-file directories, and canonical artifact identity.
 * [OUTPUT]: Provides shared artifact limits, safe relative-path validation, one-pass normalized ZIP traversal, Content Digest calculation, and declared-digest verification.
 * [POS]: Serves as the executable artifact-format contract shared by Hub producers and CLI consumers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package artifact

import (
	"archive/zip"
	"bytes"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"path"
	"path/filepath"
	"sort"
	"strings"
)

const (
	MaxArchiveBytes      = 64 << 20
	MaxFiles             = 5000
	MaxUncompressedBytes = 64 << 20
)

// Entry is one validated regular file in normalized artifact-path order.
type Entry struct {
	Path     string
	Contents []byte
	Mode     os.FileMode
	Size     int64
}

// VisitFunc observes each validated artifact file while its Content Digest is
// calculated. Contents are owned by the call and must not be retained.
type VisitFunc func(Entry) error

func ValidRelativePath(value string) bool {
	return value != "" && value != "." && !strings.HasPrefix(value, "/") &&
		!strings.Contains(value, "\\") && path.Clean(value) == value &&
		value != ".." && !strings.HasPrefix(value, "../")
}

func ValidContentDigest(value string) bool {
	if len(value) != len("sha256:")+sha256.Size*2 || !strings.HasPrefix(value, "sha256:") {
		return false
	}
	_, err := hex.DecodeString(strings.TrimPrefix(value, "sha256:"))
	return err == nil
}

func ContentDigest(data []byte, skillID, version string) (string, error) {
	return WalkContent(data, skillID, version, nil)
}

// WalkContent validates and reads an artifact exactly once, visits files in
// normalized path order, and returns the Content Digest over the same entries.
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
	prefix, hash, seen := skillID+"@"+version+"/", sha256.New(), map[string]bool{}
	var total uint64
	for _, entry := range entries {
		if entry.FileInfo().IsDir() {
			continue
		}
		if !strings.HasPrefix(entry.Name, prefix) {
			return "", fmt.Errorf("artifact file %q is outside expected prefix %q", entry.Name, prefix)
		}
		relative := strings.TrimPrefix(entry.Name, prefix)
		if !ValidRelativePath(relative) || seen[relative] {
			return "", fmt.Errorf("artifact file has invalid or duplicate path %q", relative)
		}
		seen[relative] = true
		if entry.UncompressedSize64 > MaxUncompressedBytes || total > MaxUncompressedBytes-entry.UncompressedSize64 {
			return "", fmt.Errorf("artifact expands beyond %d bytes", MaxUncompressedBytes)
		}
		total += entry.UncompressedSize64
		contents, err := ReadEntry(entry)
		if err != nil {
			return "", fmt.Errorf("read artifact file %q: %w", relative, err)
		}
		if err := WriteDigestEntry(hash, relative, contents); err != nil {
			return "", err
		}
		if visit != nil {
			if err := visit(Entry{Path: relative, Contents: contents, Mode: entry.Mode(), Size: int64(entry.UncompressedSize64)}); err != nil {
				return "", fmt.Errorf("visit artifact file %q: %w", relative, err)
			}
		}
	}
	if !seen["SKILL.md"] {
		return "", fmt.Errorf("artifact does not contain SKILL.md")
	}
	return fmt.Sprintf("sha256:%x", hash.Sum(nil)), nil
}

func DirectoryContentDigest(root string) (string, error) {
	root, err := filepath.Abs(root)
	if err != nil {
		return "", err
	}
	paths := make([]string, 0)
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
		if !ValidRelativePath(relative) {
			return fmt.Errorf("artifact contains invalid path %q", relative)
		}
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
		if err := WriteDigestEntry(hash, relative, contents); err != nil {
			return "", err
		}
	}
	if info, err := os.Stat(filepath.Join(root, "SKILL.md")); err != nil || !info.Mode().IsRegular() {
		return "", fmt.Errorf("artifact does not contain a regular SKILL.md")
	}
	return fmt.Sprintf("sha256:%x", hash.Sum(nil)), nil
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

func WriteDigestEntry(destination io.Writer, relative string, contents []byte) error {
	if err := binary.Write(destination, binary.BigEndian, uint64(len(relative))); err != nil {
		return err
	}
	if _, err := io.WriteString(destination, relative); err != nil {
		return err
	}
	if err := binary.Write(destination, binary.BigEndian, uint64(len(contents))); err != nil {
		return err
	}
	_, err := destination.Write(contents)
	return err
}

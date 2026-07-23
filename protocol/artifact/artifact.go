/*
 * [INPUT]: Depends on immutable Repository file inventories and ZIP bytes, extracted regular-file directories, and canonical Repository identity.
 * [OUTPUT]: Provides deterministic Repository ZIP construction, shared limits, portable collision-safe paths, canonical modes, one-pass traversal, and Go-compatible Sum calculation.
 * [POS]: Serves as the executable Repository Artifact format contract shared by Hub producers and CLI consumers.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package artifact

import (
	"archive/zip"
	"bytes"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"os"
	"path"
	"path/filepath"
	"sort"
	"strings"
	"time"
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

// BuildRepository serializes one complete validated Repository file inventory
// beneath the canonical <repositoryID>@<version>/ ZIP prefix.
func BuildRepository(repositoryID, version string, files []Entry) ([]byte, error) {
	if repositoryID == "" || version == "" {
		return nil, errors.New("Repository Artifact identity and version are required")
	}
	if len(files) == 0 || len(files) > MaxFiles {
		return nil, fmt.Errorf("Repository Artifact file count must be between 1 and %d", MaxFiles)
	}
	files = append([]Entry(nil), files...)
	sort.Slice(files, func(i, j int) bool { return files[i].Path < files[j].Path })
	var total uint64
	for _, file := range files {
		if file.Directory {
			return nil, fmt.Errorf("Repository Artifact input %q is a directory; only regular files are accepted", file.Path)
		}
		size := uint64(len(file.Contents))
		if size > MaxUncompressedBytes || total > MaxUncompressedBytes-size {
			return nil, fmt.Errorf("Repository Artifact exceeds %d bytes", MaxUncompressedBytes)
		}
		total += size
	}

	var buffer bytes.Buffer
	writer := zip.NewWriter(&buffer)
	prefix := repositoryID + "@" + version + "/"
	for _, file := range files {
		header := &zip.FileHeader{Name: prefix + file.Path, Method: zip.Deflate}
		header.Modified = time.Date(1980, time.January, 1, 0, 0, 0, 0, time.UTC)
		mode, err := canonicalRegularMode(file.Mode)
		if err != nil {
			_ = writer.Close()
			return nil, fmt.Errorf("Repository Artifact file %q: %w", file.Path, err)
		}
		header.SetMode(mode)
		entry, err := writer.CreateHeader(header)
		if err != nil {
			_ = writer.Close()
			return nil, fmt.Errorf("create Repository Artifact file %q: %w", file.Path, err)
		}
		if _, err := entry.Write(file.Contents); err != nil {
			_ = writer.Close()
			return nil, fmt.Errorf("write Repository Artifact file %q: %w", file.Path, err)
		}
	}
	if err := writer.Close(); err != nil {
		return nil, fmt.Errorf("close Repository Artifact ZIP: %w", err)
	}
	if buffer.Len() > MaxArchiveBytes {
		return nil, fmt.Errorf("Repository Artifact archive exceeds %d bytes", MaxArchiveBytes)
	}
	archive := buffer.Bytes()
	if _, err := RepositorySum(archive, repositoryID, version); err != nil {
		return nil, err
	}
	return archive, nil
}

func canonicalRegularMode(mode os.FileMode) (os.FileMode, error) {
	if mode == 0 {
		return 0o644, nil
	}
	if mode&os.ModeType != 0 {
		return 0, errors.New("mode is not regular")
	}
	if mode.Perm()&0o111 != 0 {
		return 0o755, nil
	}
	return 0o644, nil
}

// RepositorySum validates an immutable Repository ZIP and returns the Sum over
// all prefix-free regular files in the Repository Artifact.
func RepositorySum(data []byte, repositoryID, version string) (string, error) {
	return WalkRepository(data, repositoryID, version, nil)
}

// WalkRepository validates and reads one complete Repository Artifact exactly
// once, visits entries in normalized path order, and returns its Sum.
func WalkRepository(data []byte, repositoryID, version string, visit VisitFunc) (string, error) {
	return walkContent(data, repositoryID, version, visit)
}

func walkContent(data []byte, artifactID, version string, visit VisitFunc) (string, error) {
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
	prefix, hash, seen := artifactID+"@"+version+"/", sha256.New(), map[string]seenPath{}
	var total uint64
	hasSkill := false
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
		if path.Base(relative) == "SKILL.md" {
			hasSkill = true
		}
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
	if !hasSkill {
		return "", fmt.Errorf("Repository Artifact does not contain a SKILL.md member")
	}
	return "h1:" + base64.StdEncoding.EncodeToString(hash.Sum(nil)), nil
}

// RepositoryDirectorySum calculates the Repository Sum for an extracted
// Repository Artifact whose Skill members may be rooted or nested.
func RepositoryDirectorySum(root string) (string, error) {
	return directorySum(root)
}

func directorySum(root string) (string, error) {
	root, err := filepath.Abs(root)
	if err != nil {
		return "", err
	}
	paths := make([]string, 0)
	seen := make(map[string]string)
	var total uint64
	hasSkill := false
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
		if path.Base(relative) == "SKILL.md" {
			hasSkill = true
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
		if err := writeHash1Content(hash, relative, contents); err != nil {
			return "", err
		}
	}
	if !hasSkill {
		return "", fmt.Errorf("Repository Artifact does not contain a SKILL.md member")
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
